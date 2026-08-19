defmodule Quintal.Blogrolls do
  @moduledoc """
  O blogroll, "quem eu leio" (spec 5.1, features 2 e 6; marco m3):
  lista curada e pública de cantos, descoberta como ato de amor público.

  `atualizar/2` escreve o record único `place.quintal.canto.blogroll`
  (`literal:self`, spec 10.4) no pds da pessoa e indexa otimista;
  `indexar/2` é o upsert por `dono_did` compartilhado com
  `Quintal.Ingestao` e o backfill do `Quintal.Bootstrap`.
  """

  import Ecto.Query

  alias Quintal.Blogroll
  alias Quintal.Identidade
  alias Quintal.Repo

  require Logger

  @blogroll "place.quintal.canto.blogroll"

  @doc """
  Substitui o blogroll inteiro: escreve o record no pds e indexa
  otimista.

  `items` é uma lista de `%{did:, note:}` (chaves atom ou string);
  `note` é opcional. Todo did precisa ser de quem já tem canto no
  quintal: desconhecido é `{:error, :canto_desconhecido}` e nada sai de
  casa.
  """
  @spec atualizar(Quintal.PDS.session(), items :: [map()]) ::
          {:ok, Blogroll.t()} | {:error, :canto_desconhecido | term()}
  def atualizar(session, items) when is_list(items) do
    normalizados = Enum.map(items, &normaliza_item/1)

    with :ok <- cantos_conhecidos(normalizados) do
      record = %{"items" => normalizados, "updatedAt" => DateTime.to_iso8601(DateTime.utc_now())}

      with {:ok, %{uri: _uri, cid: _cid}} <- pds().put_record(session, @blogroll, "self", record, []) do
        indexar(session.did, %{value: record})
      end
    end
  end

  @doc "O blogroll de um canto, com a identidade do dono. `nil` quando a pessoa ainda não montou o dela."
  @spec get(dono_did :: String.t()) :: Blogroll.t() | nil
  def get(dono_did) do
    case Repo.get(Blogroll, dono_did) do
      %Blogroll{} = blogroll -> Repo.preload(blogroll, :dono)
      nil -> nil
    end
  end

  @doc """
  Upsert idempotente do blogroll no índice.

  `value` é o record decodificado: chaves atom quando vem do XRPC,
  chaves string no formato do lexicon quando vem da escrita otimista ou
  da firehose.
  """
  @spec indexar(dono_did :: String.t(), %{value: map()}) ::
          {:ok, Blogroll.t()} | {:error, Ecto.Changeset.t() | :record_inesperado}
  def indexar(dono_did, %{value: value}) when is_map(value) do
    attrs = %{
      dono_did: dono_did,
      items: campo(value, :items) || [],
      updated_at: parse_datetime(campo(value, :updated_at) || campo(value, :updatedAt))
    }

    %Blogroll{}
    |> Blogroll.changeset(attrs)
    |> Repo.insert(on_conflict: {:replace, [:items, :updated_at]}, conflict_target: :dono_did)
    |> case do
      {:ok, blogroll} ->
        {:ok, blogroll}

      {:error, changeset} ->
        Logger.warning("[#{__MODULE__}] blogroll de #{dono_did} fora do índice: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  def indexar(_dono_did, record) do
    Logger.warning("[#{__MODULE__}] record inesperado na indexação: #{inspect(record)}")
    {:error, :record_inesperado}
  end

  defp normaliza_item(item) when is_map(item) do
    case campo(item, :note) do
      note when is_binary(note) -> %{"did" => campo(item, :did), "note" => note}
      _sem_note -> %{"did" => campo(item, :did)}
    end
  end

  defp cantos_conhecidos(items) do
    dids = items |> Enum.map(& &1["did"]) |> Enum.reject(&is_nil/1) |> Enum.uniq()
    conhecidos = Repo.all(from i in Identidade, where: i.did in ^dids, select: i.did)

    if length(conhecidos) == length(dids), do: :ok, else: {:error, :canto_desconhecido}
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
