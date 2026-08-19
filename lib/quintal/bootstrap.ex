defmodule Quintal.Bootstrap do
  @moduledoc """
  O que acontece depois do consentimento (spec 8.2, fluxo 1): garante o
  record `canto.config` no repo da pessoa, indexa a identidade e faz o
  backfill do que ela já escreveu no pds (prosas, follows, recados,
  depoimentos) mais os records únicos (canto.config, blogroll).

  Tudo idempotente: roda a cada login, não só no primeiro. Falha aqui
  nunca derruba o login. roda numa Task supervisionada fora do request.

  ponytail: Task.Supervisor basta no alpha; Oban entra no m2 com os
  jobs recorrentes (cache de blobs, eventos de visitas).
  """

  alias Quintal.Blogrolls
  alias Quintal.Cantos
  alias Quintal.Depoimentos
  alias Quintal.Follows
  alias Quintal.Identidade
  alias Quintal.Prosas
  alias Quintal.Recados
  alias Quintal.Repo

  require Logger

  @canto_config "place.quintal.canto.config"
  @follow "place.quintal.graph.follow"
  @prosa "place.quintal.feed.prosa"
  @recado "place.quintal.canto.recado"
  @depoimento "place.quintal.canto.depoimento"
  @blogroll "place.quintal.canto.blogroll"

  @blocos_padrao ~w(bio prosas recados quem-eu-leio links)

  @doc "Garante canto.config, indexa a identidade e faz o backfill das prosas, follows, recados, depoimentos e blogroll."
  @spec run(Quintal.PDS.session()) :: :ok
  def run(session) do
    with :ok <- index_identidade(session),
         :ok <- ensure_canto_config(session) do
      backfill(session, @prosa, &Prosas.indexar/2)
      backfill(session, @follow, &Follows.indexar/2)
      backfill(session, @recado, &Recados.indexar/2)
      backfill(session, @depoimento, &Depoimentos.indexar/2)
      backfill_blogroll(session)
    else
      {:error, reason} ->
        Logger.warning("[#{__MODULE__}] bootstrap de #{session.did} falhou: #{inspect(reason)}")
    end

    :ok
  end

  defp index_identidade(session) do
    attrs = %{
      did: session.did,
      handle: session.handle || session.did,
      pds_url: session.service_url,
      atualizado_em: DateTime.utc_now()
    }

    %Identidade{}
    |> Identidade.changeset(attrs)
    |> Repo.insert(
      on_conflict: [set: [handle: attrs.handle, pds_url: attrs.pds_url, atualizado_em: attrs.atualizado_em]],
      conflict_target: :did
    )
    |> case do
      {:ok, _identidade} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp ensure_canto_config(session) do
    case pds().get_record(session, session.did, @canto_config, "self") do
      {:ok, record} ->
        index_singleton(session.did, record, &Cantos.indexar/2)

      {:error, _not_found} ->
        config = %{
          "tema" => "papel",
          "blocos" => @blocos_padrao,
          "updatedAt" => DateTime.to_iso8601(DateTime.utc_now())
        }

        case pds().put_record(session, @canto_config, "self", config, []) do
          {:ok, _written} -> :ok
          {:error, _} = error -> error
        end
    end
  end

  defp backfill_blogroll(session) do
    case pds().get_record(session, session.did, @blogroll, "self") do
      {:ok, record} -> index_singleton(session.did, record, &Blogrolls.indexar/2)
      {:error, _ausente} -> :ok
    end
  end

  # Singleton pode não existir ou vir sem o valor decodificado: não é erro.
  defp index_singleton(did, %{value: value}, indexar) when is_map(value) do
    case indexar.(did, %{value: value}) do
      {:ok, _indexado} -> :ok
      {:error, _fora_do_indice} -> :ok
    end
  end

  defp index_singleton(_did, _sem_valor, _indexar), do: :ok

  defp backfill(session, collection, indexar, cursor \\ nil) do
    opts = if cursor, do: [limit: 100, cursor: cursor], else: [limit: 100]

    case pds().list_records(session, session.did, collection, opts) do
      {:ok, %{records: records} = page} ->
        Enum.each(records, &indexar.(session.did, &1))

        case Map.get(page, :cursor) do
          nil -> :ok
          next -> backfill(session, collection, indexar, next)
        end

      {:error, _} = error ->
        error
    end
  end

  defp pds, do: Quintal.PDS.impl()
end
