defmodule Quintal.Cantos do
  @moduledoc """
  A arrumação do canto (spec 5.1, feature 1, e 7.2; marco m3): preset de
  tema (papel, madrugada, gloss), cor de acento opcional, ordem dos
  blocos do arrastar e soltar, bio e links.

  `arrumar/2` escreve o record único `place.quintal.canto.config`
  (`literal:self`, spec 10.5) no pds da pessoa e indexa otimista;
  `indexar/2` é o upsert por `dono_did` compartilhado com
  `Quintal.Ingestao` e o backfill do `Quintal.Bootstrap`. A decoração
  também é portátil: a ordem dos blocos vive no record.

  O `nome` de exibição é a exceção local: não entra no record, não vai
  pro pds, é cosmético do appview. Trocar só o nome não toca na rede.

  Tema e blocos são validados pelo changeset do `Quintal.Canto` antes de
  qualquer escrita: falhar cedo, falhar em casa (spec 9.4).
  """

  alias Quintal.Canto
  alias Quintal.Repo

  require Logger

  @canto_config "place.quintal.canto.config"

  @blocos_padrao ~w(bio prosas recados quem-eu-leio links)

  @doc "A configuração do canto de uma pessoa, com a identidade do dono. `nil` quando nunca foi indexada."
  @spec get(dono_did :: String.t()) :: Canto.t() | nil
  def get(dono_did) do
    case Repo.get(Canto, dono_did) do
      %Canto{} = canto -> Repo.preload(canto, :dono)
      nil -> nil
    end
  end

  @doc """
  Arruma o canto: mescla `attrs` sobre a configuração atual, escreve o
  record no pds e indexa otimista.

  `attrs` pode trazer `:tema`, `:cor`, `:blocos`, `:bio`, `:links` e
  `:nome` (chaves atom ou string); o que não vier fica como está, e o
  que nunca existiu cai no padrão (tema papel, todos os blocos
  visíveis). `cor` `nil` ou `""` tira o acento do record. O `:nome` é
  local do appview: quando é a única mudança, nem rede acontece.

  Tema fora dos presets ou bloco desconhecido falham em casa, antes da
  rede.
  """
  @spec arrumar(Quintal.PDS.session(), attrs :: map()) :: {:ok, Canto.t()} | {:error, Ecto.Changeset.t() | term()}
  def arrumar(session, attrs) when is_map(attrs) do
    if so_nome?(attrs) do
      arrumar_nome(session.did, attrs |> fetch(:nome) |> elem(1))
    else
      arrumar_config(session, attrs)
    end
  end

  defp arrumar_config(session, attrs) do
    config =
      session.did
      |> config_atual()
      |> mescla(attrs)

    params = Map.merge(config, %{dono_did: session.did, updated_at: DateTime.utc_now()})
    changeset = Canto.changeset(%Canto{}, params)

    if changeset.valid? do
      record = monta_record(changeset)

      with {:ok, %{uri: _uri, cid: _cid}} <- pds().put_record(session, @canto_config, "self", record, []),
           {:ok, canto} <- indexar(session.did, %{value: record}) do
        guardar_nome_local(session.did, attrs, canto)
      end
    else
      {:error, changeset}
    end
  end

  # o nome é local: depois do record escrito, ele entra por fora
  defp guardar_nome_local(dono_did, attrs, canto) do
    case fetch(attrs, :nome) do
      {:ok, nome} -> arrumar_nome(dono_did, nome)
      :ausente -> {:ok, canto}
    end
  end

  defp so_nome?(attrs) do
    (Map.has_key?(attrs, :nome) or Map.has_key?(attrs, "nome")) and map_size(attrs) == 1
  end

  # nome de exibição: coluna local, sem record, sem pds. vazio tira o
  # nome e a casa volta a se apresentar pelo handle.
  defp arrumar_nome(dono_did, nome) do
    nome = if is_binary(nome), do: String.trim(nome)
    nome = if nome in [nil, ""], do: nil, else: nome

    case Repo.get(Canto, dono_did) do
      %Canto{} = canto ->
        canto
        |> Canto.changeset(%{nome: nome})
        |> Repo.update()

      nil ->
        %Canto{}
        |> Canto.changeset(%{
          dono_did: dono_did,
          nome: nome,
          tema: "papel",
          blocos: @blocos_padrao,
          links: [],
          updated_at: DateTime.utc_now()
        })
        |> Repo.insert()
    end
  end

  @doc "Os nomes de exibição dos dids dados, como `%{did => nome}`. Só quem escolheu um aparece."
  @spec nomes([String.t()]) :: %{String.t() => String.t()}
  def nomes(dids) do
    import Ecto.Query

    from(c in Canto,
      where: c.dono_did in ^dids and not is_nil(c.nome),
      select: {c.dono_did, c.nome}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Upsert idempotente da configuração do canto no índice.

  `value` é o record decodificado: chaves atom quando vem do XRPC,
  chaves string no formato do lexicon quando vem da escrita otimista ou
  da firehose.
  """
  @spec indexar(dono_did :: String.t(), %{value: map()}) ::
          {:ok, Canto.t()} | {:error, Ecto.Changeset.t() | :record_inesperado}
  def indexar(dono_did, %{value: value}) when is_map(value) do
    attrs = %{
      dono_did: dono_did,
      tema: campo(value, :tema),
      cor: campo(value, :cor),
      blocos: campo(value, :blocos),
      bio: campo(value, :bio),
      links: campo(value, :links) || [],
      updated_at: parse_datetime(campo(value, :updated_at) || campo(value, :updatedAt))
    }

    %Canto{}
    |> Canto.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:tema, :cor, :blocos, :bio, :links, :updated_at]},
      conflict_target: :dono_did
    )
    |> case do
      {:ok, canto} ->
        {:ok, canto}

      {:error, changeset} ->
        Logger.warning("[#{__MODULE__}] canto de #{dono_did} fora do índice: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  def indexar(_dono_did, record) do
    Logger.warning("[#{__MODULE__}] record inesperado na indexação: #{inspect(record)}")
    {:error, :record_inesperado}
  end

  defp config_atual(dono_did) do
    case Repo.get(Canto, dono_did) do
      %Canto{} = canto ->
        links = Enum.map(canto.links, &%{titulo: &1.titulo, url: &1.url})
        %{tema: canto.tema, cor: canto.cor, blocos: canto.blocos, bio: canto.bio, links: links}

      nil ->
        %{tema: "papel", cor: nil, blocos: @blocos_padrao, bio: nil, links: []}
    end
  end

  defp mescla(config, attrs) do
    Enum.reduce([:tema, :cor, :blocos, :bio, :links], config, fn chave, acc ->
      case busca_attr(attrs, chave) do
        {:ok, valor} -> Map.put(acc, chave, valor)
        :ausente -> acc
      end
    end)
  end

  # cor vazia tira o acento do canto; bio vazia segue escrita, é texto da pessoa.
  defp busca_attr(attrs, :cor) do
    case fetch(attrs, :cor) do
      {:ok, cor} when cor in [nil, ""] -> {:ok, nil}
      outro -> outro
    end
  end

  defp busca_attr(attrs, chave), do: fetch(attrs, chave)

  defp fetch(attrs, chave) do
    if Map.has_key?(attrs, chave) do
      {:ok, Map.get(attrs, chave)}
    else
      if Map.has_key?(attrs, Atom.to_string(chave)),
        do: {:ok, Map.get(attrs, Atom.to_string(chave))},
        else: :ausente
    end
  end

  defp monta_record(changeset) do
    record = %{
      "tema" => Ecto.Changeset.get_field(changeset, :tema),
      "blocos" => Ecto.Changeset.get_field(changeset, :blocos),
      "updatedAt" => changeset |> Ecto.Changeset.get_field(:updated_at) |> DateTime.to_iso8601()
    }

    record =
      case Ecto.Changeset.get_field(changeset, :cor) do
        nil -> record
        cor -> Map.put(record, "cor", cor)
      end

    record =
      case Ecto.Changeset.get_field(changeset, :bio) do
        nil -> record
        bio -> Map.put(record, "bio", bio)
      end

    case Ecto.Changeset.get_field(changeset, :links) do
      [] -> record
      links -> Map.put(record, "links", Enum.map(links, &%{"titulo" => &1.titulo, "url" => &1.url}))
    end
  end

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
