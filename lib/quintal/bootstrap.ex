defmodule Quintal.Bootstrap do
  @moduledoc """
  O que acontece depois do consentimento (spec 8.2, fluxo 1): garante o
  record `canto.config` no repo da pessoa, indexa a identidade e faz o
  backfill das prosas já escritas no pds.

  Tudo idempotente: roda a cada login, não só no primeiro. Falha aqui
  nunca derruba o login — roda numa Task supervisionada fora do request.

  ponytail: Task.Supervisor basta no alpha; Oban entra no m2 com os
  jobs recorrentes (cache de blobs, eventos de visitas).
  """

  alias Quintal.Identidade
  alias Quintal.Prosa
  alias Quintal.Repo

  require Logger

  @canto_config "place.quintal.canto.config"
  @prosa "place.quintal.feed.prosa"

  @blocos_padrao ~w(bio prosas recados quem-eu-leio links)

  @doc "Garante canto.config, indexa a identidade e faz o backfill das prosas."
  @spec run(Quintal.PDS.session()) :: :ok
  def run(session) do
    with :ok <- index_identidade(session),
         :ok <- ensure_canto_config(session) do
      backfill_prosas(session)
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
      {:ok, _record} ->
        :ok

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

  defp backfill_prosas(session, cursor \\ nil) do
    opts = if cursor, do: [limit: 100, cursor: cursor], else: [limit: 100]

    case pds().list_records(session, session.did, @prosa, opts) do
      {:ok, %{records: records} = page} ->
        Enum.each(records, &upsert_prosa(session.did, &1))

        case Map.get(page, :cursor) do
          nil -> :ok
          next -> backfill_prosas(session, next)
        end

      {:error, _} = error ->
        error
    end
  end

  defp upsert_prosa(autor_did, %{uri: uri, cid: cid, value: value}) do
    attrs = %{
      uri: uri,
      autor_did: autor_did,
      cid: cid,
      texto: Map.get(value, :text),
      tipo: Map.get(value, :tipo),
      reply_root: get_in(value, [:reply, :root, :uri]),
      reply_parent: get_in(value, [:reply, :parent, :uri]),
      langs: Map.get(value, :langs),
      created_at: parse_datetime(Map.get(value, :created_at)),
      indexed_at: DateTime.utc_now()
    }

    %Prosa{}
    |> Prosa.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:cid, :texto, :tipo, :reply_root, :reply_parent, :langs, :created_at, :indexed_at]},
      conflict_target: :uri
    )
    |> case do
      {:ok, _prosa} ->
        :ok

      {:error, changeset} ->
        Logger.warning("[#{__MODULE__}] prosa #{uri} fora do índice: #{inspect(changeset.errors)}")
    end
  end

  defp upsert_prosa(_autor_did, record) do
    Logger.warning("[#{__MODULE__}] record inesperado no backfill: #{inspect(record)}")
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
