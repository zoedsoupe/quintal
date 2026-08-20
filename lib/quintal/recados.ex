defmodule Quintal.Recados do
  @moduledoc """
  O livro de visitas (spec 5.1, feature 5; marco m3): qualquer pessoa
  pode deixar recado em qualquer canto.

  `deixar/3` escreve o record `place.quintal.canto.recado` no repo de
  quem escreve e indexa otimista; o eco do firehose chega como o mesmo
  evento, então a indexação é upsert por `uri` (`indexar/2`,
  compartilhado com `Quintal.Ingestao` e o backfill do
  `Quintal.Bootstrap`).

  O dono do canto pode ocultar (`ocultar/2`), e o ocultar é flag local
  do índice: o record fica intacto no pds de quem escreveu. Sua fala,
  seu repo; minha parede, minhas regras.
  """

  import Ecto.Query

  alias Quintal.Identidade
  alias Quintal.Recado
  alias Quintal.Repo
  alias Quintal.VisitaEvento
  alias Quintal.Visitas

  require Logger

  @recado "place.quintal.canto.recado"

  @doc """
  Deixa um recado num canto: escreve o record no pds de quem escreve e
  indexa otimista.

  `identificador` é handle ou did de quem já tem canto no quintal.
  Identidade desconhecida é `{:error, :canto_desconhecido}`; recado no
  próprio canto é `{:error, :recado_proprio_canto}`. Texto em branco
  falha em casa, antes da rede.
  """
  @spec deixar(Quintal.PDS.session(), identificador :: String.t(), texto :: String.t()) ::
          {:ok, Recado.t()} | {:error, :texto_vazio | :canto_desconhecido | :recado_proprio_canto | term()}
  def deixar(session, identificador, texto) when is_binary(identificador) and is_binary(texto) do
    with :ok <- texto_presente(texto),
         {:ok, subject} <- busca_identidade(String.trim(identificador)),
         :ok <- recusa_proprio_canto(session.did, subject.did) do
      record = %{
        "subject" => subject.did,
        "text" => texto,
        "createdAt" => DateTime.to_iso8601(DateTime.utc_now())
      }

      with {:ok, %{uri: uri, cid: _cid}} <- pds().create_record(session, @recado, record) do
        indexar(session.did, %{uri: uri, value: record})
      end
    end
  end

  defp texto_presente(texto) do
    if String.trim(texto) == "", do: {:error, :texto_vazio}, else: :ok
  end

  @doc "Oculta um recado do canto da pessoa. Só o dono do canto; o record no pds fica intacto."
  @spec ocultar(Quintal.PDS.session(), uri :: String.t()) :: {:ok, Recado.t()} | {:error, :recado_fora_do_canto}
  def ocultar(session, uri), do: alternar_oculto(session, uri, true)

  @doc "Mostra de volta um recado oculto. Só o dono do canto."
  @spec mostrar(Quintal.PDS.session(), uri :: String.t()) :: {:ok, Recado.t()} | {:error, :recado_fora_do_canto}
  def mostrar(session, uri), do: alternar_oculto(session, uri, false)

  @doc """
  Lista os recados de um canto, do mais novo para o mais antigo, com a
  identidade de quem escreveu.

  O dono do canto vê também os ocultos; qualquer outra pessoa, só os
  visíveis. A lista é limitada (@maximo_recados): ela inteira vai para o
  assigns do LiveView, e canto popular não pode virar diff gigante.
  Paginação por cursor entra quando algum canto passar disso.
  """
  @maximo_recados 100

  @spec listar_por_canto(dono_did :: String.t(), viewer_did :: String.t() | nil) :: [Recado.t()]
  def listar_por_canto(dono_did, viewer_did) do
    query =
      from r in Recado,
        where: r.subject_did == ^dono_did,
        order_by: [desc: r.created_at],
        limit: @maximo_recados,
        preload: [:autor]

    query =
      if viewer_did == dono_did do
        query
      else
        where(query, [r], r.oculto == false)
      end

    Repo.all(query)
  end

  @doc """
  Upsert idempotente de um recado no índice.

  `value` é o record decodificado: chaves atom quando vem do XRPC,
  chaves string no formato do lexicon quando vem da escrita otimista ou
  da firehose. O conflito substitui só as colunas do record: `oculto` é
  decisão local do dono do canto e sobrevive ao eco.
  """
  @spec indexar(autor_did :: String.t(), %{uri: String.t(), value: map()}) ::
          {:ok, Recado.t()} | {:error, Ecto.Changeset.t() | :record_inesperado}
  def indexar(autor_did, %{uri: uri, value: value}) when is_map(value) do
    attrs = %{
      uri: uri,
      autor_did: autor_did,
      subject_did: campo(value, :subject),
      texto: campo(value, :text),
      created_at: parse_datetime(campo(value, :created_at) || campo(value, :createdAt))
    }

    %Recado{}
    |> Recado.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:texto, :created_at]},
      conflict_target: :uri,
      returning: true
    )
    |> case do
      {:ok, recado} ->
        Visitas.registrar(recado.subject_did, "recado", uri, autor_did)
        {:ok, recado}

      {:error, changeset} ->
        Logger.warning("[#{__MODULE__}] recado #{uri} fora do índice: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  def indexar(_autor_did, record) do
    Logger.warning("[#{__MODULE__}] record inesperado na indexação: #{inspect(record)}")
    {:error, :record_inesperado}
  end

  @doc "Remove um recado do índice (delete vindo da firehose), junto com o evento de visita."
  @spec desindexar(uri :: String.t()) :: :ok
  def desindexar(uri) do
    Repo.delete_all(from r in Recado, where: r.uri == ^uri)
    Repo.delete_all(from e in VisitaEvento, where: e.ref_uri == ^uri)
    :ok
  end

  defp alternar_oculto(session, uri, oculto) do
    case Repo.get(Recado, uri) do
      %Recado{subject_did: subject_did} = recado when subject_did == session.did ->
        recado
        |> Ecto.Changeset.change(oculto: oculto)
        |> Repo.update()

      _fora_do_canto ->
        {:error, :recado_fora_do_canto}
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

  defp recusa_proprio_canto(did, did), do: {:error, :recado_proprio_canto}
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
