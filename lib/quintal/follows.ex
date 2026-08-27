defmodule Quintal.Follows do
  @moduledoc """
  Seguir e ler (spec 5.1, feature 2; marco m2).

  `seguir/2` escreve o record `place.quintal.graph.follow` no repo da
  pessoa e indexa otimista; o eco do firehose chega como o mesmo evento,
  então a indexação é upsert por `(seguidor, seguido)` (`indexar/2`,
  compartilhado com `Quintal.Ingestao` e o backfill do
  `Quintal.Bootstrap`).

  O identificador de entrada é handle ou did, resolvido no índice local
  de identidades: no alpha fechado, só dá para seguir quem já tem canto
  no quintal.
  """

  import Ecto.Query

  alias Quintal.Cantos
  alias Quintal.Follow
  alias Quintal.Identidade
  alias Quintal.Repo
  alias Quintal.Visitas

  require Logger

  @follow "place.quintal.graph.follow"

  @doc """
  Segue um canto: escreve o follow no pds da pessoa e indexa otimista.

  `identificador` é handle ou did de quem já tem canto no quintal.
  Identidade desconhecida é `{:error, :canto_desconhecido}`; seguir a si
  mesma é `{:error, :auto_follow}`. Seguir quem já é seguido é idempotente.
  """
  @spec seguir(Quintal.PDS.session(), identificador :: String.t()) ::
          {:ok, Follow.t()} | {:error, :canto_desconhecido | :auto_follow | term()}
  def seguir(session, identificador) when is_binary(identificador) do
    identificador = String.trim(identificador)

    with {:ok, seguido} <- busca_identidade(identificador),
         :ok <- recusa_auto_follow(session.did, seguido.did) do
      record = %{"subject" => seguido.did, "createdAt" => DateTime.to_iso8601(DateTime.utc_now())}

      with {:ok, %{uri: uri, cid: _cid}} <- pds().create_record(session, @follow, record) do
        indexar(session.did, %{uri: uri, value: record})
      end
    end
  end

  @doc """
  Deixa de seguir: apaga o record do pds e do índice.

  Só apaga follow do próprio repo: uri fora do repo da sessão é
  `{:error, :follow_alheio}` e nada sai de casa.
  """
  @spec deixar_de_seguir(Quintal.PDS.session(), uri :: String.t()) :: :ok | {:error, term()}
  def deixar_de_seguir(session, "at://" <> rest = uri) do
    with [did, @follow, rkey] <- String.split(rest, "/"),
         true <- did == session.did,
         :ok <- pds().delete_record(session, @follow, rkey, []) do
      desindexar(uri)
    else
      {:error, _do_pds} = error -> error
      _other -> {:error, :follow_alheio}
    end
  end

  def deixar_de_seguir(_session, _uri), do: {:error, :follow_alheio}

  @doc "Lista os cantos que a pessoa lê, com a identidade de cada um."
  @spec vizinhanca(did :: String.t()) :: [Follow.t()]
  def vizinhanca(did) do
    Repo.all(
      from f in Follow,
        where: f.seguidor_did == ^did,
        order_by: [desc: f.created_at],
        preload: [:seguido]
    )
  end

  @doc "A pessoa lê esse canto?"
  @spec segue?(seguidor_did :: String.t(), seguido_did :: String.t()) :: boolean()
  def segue?(seguidor_did, seguido_did) do
    Repo.exists?(
      from f in Follow,
        where: f.seguidor_did == ^seguidor_did and f.seguido_did == ^seguido_did
    )
  end

  @doc """
  As sugestões de menção do composer: handle e nome de exibição de
  cada canto que a pessoa lê, como `[%{handle, nome}]` (`nome` `nil`
  quando o canto não escolheu um). A lista vai embutida no form
  (`data-mencoes`) e o autofill filtra em casa, sem rede por tecla.
  """
  @spec mencoes(did :: String.t()) :: [%{handle: String.t(), nome: String.t() | nil}]
  def mencoes(did) do
    follows = vizinhanca(did)
    nomes = Cantos.nomes(Enum.map(follows, & &1.seguido_did))

    Enum.map(follows, fn f ->
      %{handle: f.seguido.handle, nome: Map.get(nomes, f.seguido_did)}
    end)
  end

  @doc """
  Upsert idempotente de um follow no índice.

  `value` é o record decodificado: chaves atom quando vem do XRPC
  (`%{subject:, created_at:}`), chaves string no formato do lexicon
  quando vem da escrita otimista ou da firehose (`%{"subject" => ...}`).
  """
  @spec indexar(seguidor_did :: String.t(), %{uri: String.t(), value: map()}) ::
          {:ok, Follow.t()} | {:error, Ecto.Changeset.t() | :record_inesperado}
  def indexar(seguidor_did, %{uri: uri, value: value}) when is_map(value) do
    attrs = %{
      seguidor_did: seguidor_did,
      seguido_did: campo(value, :subject),
      uri: uri,
      created_at: parse_datetime(campo(value, :created_at) || campo(value, :createdAt))
    }

    %Follow{}
    |> Follow.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:uri, :created_at]},
      conflict_target: [:seguidor_did, :seguido_did]
    )
    |> case do
      {:ok, follow} ->
        # vizinho novo te lendo avisa na página visitas (spec 7.5); o
        # registrar dedupa por (tipo, ref_uri), vale chamar em todo upsert
        Visitas.registrar(follow.seguido_did, "novo_leitor", follow.uri, follow.seguidor_did)
        {:ok, follow}

      {:error, changeset} ->
        Logger.warning("[#{__MODULE__}] follow #{uri} fora do índice: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  def indexar(_seguidor_did, record) do
    Logger.warning("[#{__MODULE__}] record inesperado na indexação: #{inspect(record)}")
    {:error, :record_inesperado}
  end

  @doc "Remove um follow do índice (delete vindo da firehose ou da interface)."
  @spec desindexar(uri :: String.t()) :: :ok
  def desindexar(uri) do
    Repo.delete_all(from f in Follow, where: f.uri == ^uri)
    :ok
  end

  defp busca_identidade(identificador) do
    case Repo.one(
           from i in Identidade,
             where: i.handle == ^identificador or i.did == ^identificador
         ) do
      %Identidade{} = identidade -> {:ok, identidade}
      nil -> {:error, :canto_desconhecido}
    end
  end

  defp recusa_auto_follow(did, did), do: {:error, :auto_follow}
  defp recusa_auto_follow(_eu, _outro), do: :ok

  defp campo(map, key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(iso) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, datetime, _offset} -> datetime
      {:error, _reason} -> nil
    end
  end

  defp pds, do: Quintal.PDS.impl()
end
