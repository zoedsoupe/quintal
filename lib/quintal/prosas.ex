defmodule Quintal.Prosas do
  @moduledoc """
  Escrever e ler prosas (spec 8.2, fluxos 2 e 3; marco m1).

  `prosear/3` escreve o record no repo da pessoa via
  `com.atproto.repo.createRecord` e indexa otimista: o eco do firehose
  vai chegar como o mesmo evento, então toda indexação é upsert por
  `uri` (`indexar/2`, compartilhado com o backfill do `Quintal.Bootstrap`).

  `apagar/2` remove o record do pds e do índice: a prosa sai dos dois
  lados, como a interface promete ("ela sai do seu pds também", spec 7.7).

  `list_por_autor/2` lê direto do índice, em ordem cronológica, sem
  ranqueamento em nenhuma camada. Paginação por cursor entra no m2,
  junto com o feed.
  """

  import Ecto.Query

  alias Quintal.Prosa
  alias Quintal.Repo

  require Logger

  @prosa "place.quintal.feed.prosa"

  @tipos ~w(nota pergunta cronica ensaio)

  @doc """
  Escreve uma prosa nova no pds da pessoa e indexa otimista.

  `tipo` é metadado interno opcional (nota, pergunta, cronica, ensaio,
  spec 10.1); `nil` deixa o campo fora do record.

  Retorna `{:ok, %Prosa{}}` com a prosa já indexada, ou `{:error, _}`
  sem efeito colateral no índice. Texto em branco falha em casa, antes
  da rede.
  """
  @spec prosear(Quintal.PDS.session(), texto :: String.t(), tipo :: String.t() | nil) ::
          {:ok, Prosa.t()} | {:error, :texto_vazio | term()}
  def prosear(session, texto, tipo \\ nil) when is_binary(texto) do
    if String.trim(texto) == "" do
      {:error, :texto_vazio}
    else
      record = %{"text" => texto, "createdAt" => DateTime.to_iso8601(DateTime.utc_now())}
      record = if tipo in @tipos, do: Map.put(record, "tipo", tipo), else: record

      with {:ok, %{uri: uri, cid: cid}} <- pds().create_record(session, @prosa, record) do
        indexar(session.did, %{uri: uri, cid: cid, value: record})
      end
    end
  end

  @doc """
  Apaga uma prosa do pds e do índice.

  Só apaga prosa da própria pessoa: uri fora do repo da sessão é
  `{:error, :prosa_alheia}` e nada sai de casa.
  """
  @spec apagar(Quintal.PDS.session(), uri :: String.t()) :: :ok | {:error, term()}
  def apagar(session, "at://" <> rest = uri) do
    with [did, @prosa, rkey] <- String.split(rest, "/"),
         true <- did == session.did,
         %Prosa{} = prosa <- Repo.get(Prosa, uri),
         :ok <- pds().delete_record(session, @prosa, rkey, []) do
      case Repo.delete(prosa) do
        {:ok, _prosa} -> :ok
        {:error, changeset} -> {:error, changeset}
      end
    else
      {:error, _do_pds} = error -> error
      _other -> {:error, :prosa_alheia}
    end
  end

  def apagar(_session, _uri), do: {:error, :prosa_alheia}

  @doc "Lista as prosas de uma pessoa, da mais nova para a mais antiga."
  @spec list_por_autor(autor_did :: String.t(), opts :: keyword()) :: [Prosa.t()]
  def list_por_autor(autor_did, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Repo.all(
      from p in Prosa,
        where: p.autor_did == ^autor_did,
        order_by: [desc: p.created_at],
        limit: ^limit
    )
  end

  @doc "Remove uma prosa do índice (delete vindo da firehose)."
  @spec desindexar(uri :: String.t()) :: :ok
  def desindexar(uri) do
    Repo.delete_all(from p in Prosa, where: p.uri == ^uri)
    :ok
  end

  @doc """
  Upsert idempotente de uma prosa no índice.

  `value` é o record decodificado: chaves atom snakelized quando vem do
  XRPC (`%{text:, created_at:}`), chaves string no formato do lexicon
  quando vem da escrita otimista (`%{"text" => ...}`).
  """
  @spec indexar(autor_did :: String.t(), %{uri: String.t(), cid: String.t(), value: map()}) ::
          {:ok, Prosa.t()} | {:error, Ecto.Changeset.t()}
  def indexar(autor_did, %{uri: uri, cid: cid, value: value}) do
    attrs = %{
      uri: uri,
      autor_did: autor_did,
      cid: cid,
      texto: campo(value, :text),
      tipo: campo(value, :tipo),
      reply_root: strong_ref_uri(campo(value, :reply), :root),
      reply_parent: strong_ref_uri(campo(value, :reply), :parent),
      langs: campo(value, :langs),
      created_at: parse_datetime(campo(value, :created_at) || campo(value, :createdAt)),
      indexed_at: DateTime.utc_now()
    }

    %Prosa{}
    |> Prosa.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:cid, :texto, :tipo, :reply_root, :reply_parent, :langs, :created_at, :indexed_at]},
      conflict_target: :uri
    )
    |> case do
      {:ok, prosa} ->
        {:ok, prosa}

      {:error, changeset} ->
        Logger.warning("[#{__MODULE__}] prosa #{uri} fora do índice: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  def indexar(_autor_did, record) do
    Logger.warning("[#{__MODULE__}] record inesperado na indexação: #{inspect(record)}")
    {:error, :record_inesperado}
  end

  # Record values arrive atom-keyed from the XRPC decode and
  # string-keyed from the optimistic write: accept both.
  defp campo(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp campo(_other, _key), do: nil

  defp strong_ref_uri(reply, papel) when is_map(reply) do
    reply |> campo(papel) |> campo(:uri)
  end

  defp strong_ref_uri(_reply, _papel), do: nil

  defp parse_datetime(nil), do: nil

  defp parse_datetime(iso) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, datetime, _offset} -> datetime
      {:error, _reason} -> nil
    end
  end

  defp pds, do: Quintal.PDS.impl()
end
