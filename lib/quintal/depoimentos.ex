defmodule Quintal.Depoimentos do
  @moduledoc """
  Depoimentos com aceite (spec 5.1, feature 6; marco m3): testemunho
  público sobre uma pessoa, que só aparece no canto dela depois de
  aceito.

  `deixar/3` escreve o record `place.quintal.canto.depoimento` no repo
  de quem escreve e indexa otimista; o eco do firehose chega como o
  mesmo evento, então a indexação é upsert por `uri` (`indexar/2`,
  compartilhado com `Quintal.Ingestao` e o backfill do
  `Quintal.Bootstrap`).

  Na v1 o aceite (`aceitar/2`, `deixar_quieto/2`) é estado local do
  appview: coluna `aceito`, `nil` até a decisão do dono do canto. O
  upsert nunca toca nessa coluna.
  """

  import Ecto.Query

  alias Quintal.Depoimento
  alias Quintal.Identidade
  alias Quintal.Repo
  alias Quintal.VisitaEvento
  alias Quintal.Visitas

  require Logger

  @depoimento "place.quintal.canto.depoimento"

  @doc """
  Deixa um depoimento num canto: escreve o record no pds de quem escreve
  e indexa otimista. Fica pendente até o aceite do dono do canto.

  `identificador` é handle ou did de quem já tem canto no quintal.
  Identidade desconhecida é `{:error, :canto_desconhecido}`; depoimento
  no próprio canto é `{:error, :depoimento_proprio_canto}`. Texto em
  branco falha em casa, antes da rede.
  """
  @spec deixar(Quintal.PDS.session(), identificador :: String.t(), texto :: String.t()) ::
          {:ok, Depoimento.t()} | {:error, :texto_vazio | :canto_desconhecido | :depoimento_proprio_canto | term()}
  def deixar(session, identificador, texto) when is_binary(identificador) and is_binary(texto) do
    with :ok <- texto_presente(texto),
         {:ok, subject} <- busca_identidade(String.trim(identificador)),
         :ok <- recusa_proprio_canto(session.did, subject.did) do
      record = %{
        "subject" => subject.did,
        "text" => texto,
        "createdAt" => DateTime.to_iso8601(DateTime.utc_now())
      }

      with {:ok, %{uri: uri, cid: _cid}} <- pds().create_record(session, @depoimento, record) do
        indexar(session.did, %{uri: uri, value: record})
      end
    end
  end

  defp texto_presente(texto) do
    if String.trim(texto) == "", do: {:error, :texto_vazio}, else: :ok
  end

  @doc "Aceita um depoimento: passa a aparecer no canto. Só o dono do canto."
  @spec aceitar(Quintal.PDS.session(), uri :: String.t()) :: {:ok, Depoimento.t()} | {:error, :depoimento_alheio}
  def aceitar(session, uri), do: decidir(session, uri, true)

  @doc "Deixa quieto: o depoimento não aparece no canto. Só o dono do canto."
  @spec deixar_quieto(Quintal.PDS.session(), uri :: String.t()) :: {:ok, Depoimento.t()} | {:error, :depoimento_alheio}
  def deixar_quieto(session, uri), do: decidir(session, uri, false)

  @doc "Os depoimentos esperando decisão do dono do canto, do mais novo para o mais antigo."
  @spec pendentes(dono_did :: String.t()) :: [Depoimento.t()]
  def pendentes(dono_did) do
    Repo.all(
      from d in Depoimento,
        where: d.subject_did == ^dono_did and is_nil(d.aceito),
        order_by: [desc: d.created_at],
        preload: [:autor]
    )
  end

  @doc "Os depoimentos aceitos que aparecem no canto, do mais novo para o mais antigo."
  @spec aceitos(dono_did :: String.t()) :: [Depoimento.t()]
  def aceitos(dono_did) do
    Repo.all(
      from d in Depoimento,
        where: d.subject_did == ^dono_did and d.aceito == true,
        order_by: [desc: d.created_at],
        preload: [:autor]
    )
  end

  @doc """
  Upsert idempotente de um depoimento no índice.

  `value` é o record decodificado: chaves atom quando vem do XRPC,
  chaves string no formato do lexicon quando vem da escrita otimista ou
  da firehose. O conflito substitui só as colunas do record: `aceito` é
  decisão local do dono do canto e sobrevive ao eco.
  """
  @spec indexar(autor_did :: String.t(), %{uri: String.t(), value: map()}) ::
          {:ok, Depoimento.t()} | {:error, Ecto.Changeset.t() | :record_inesperado}
  def indexar(autor_did, %{uri: uri, value: value}) when is_map(value) do
    attrs = %{
      uri: uri,
      autor_did: autor_did,
      subject_did: campo(value, :subject),
      texto: campo(value, :text),
      created_at: parse_datetime(campo(value, :created_at) || campo(value, :createdAt))
    }

    %Depoimento{}
    |> Depoimento.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:texto, :created_at]},
      conflict_target: :uri,
      returning: true
    )
    |> case do
      {:ok, depoimento} ->
        Visitas.registrar(depoimento.subject_did, "depoimento", uri, autor_did)
        {:ok, depoimento}

      {:error, changeset} ->
        Logger.warning("[#{__MODULE__}] depoimento #{uri} fora do índice: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  def indexar(_autor_did, record) do
    Logger.warning("[#{__MODULE__}] record inesperado na indexação: #{inspect(record)}")
    {:error, :record_inesperado}
  end

  @doc "Remove um depoimento do índice (delete vindo da firehose), junto com o evento de visita."
  @spec desindexar(uri :: String.t()) :: :ok
  def desindexar(uri) do
    Repo.delete_all(from d in Depoimento, where: d.uri == ^uri)
    Repo.delete_all(from e in VisitaEvento, where: e.ref_uri == ^uri)
    :ok
  end

  defp decidir(session, uri, aceito) do
    case Repo.get(Depoimento, uri) do
      %Depoimento{subject_did: subject_did} = depoimento when subject_did == session.did ->
        depoimento
        |> Ecto.Changeset.change(aceito: aceito)
        |> Repo.update()

      _alheio ->
        {:error, :depoimento_alheio}
    end
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

  defp recusa_proprio_canto(did, did), do: {:error, :depoimento_proprio_canto}
  defp recusa_proprio_canto(_eu, _outro), do: :ok

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
