defmodule Quintal.Ingestao do
  @moduledoc """
  O consumidor do jetstream (spec 8.1 e 9.5; marco m2).

  Assina `ProtoRune.Jetstream` filtrando as coleções `place.quintal.*`
  no servidor — ao contrário do firehose cru, só o que é do quintal
  chega aqui — mais os eventos de identidade, e mantém o índice
  postgres em sincronia:

    * create/update de prosa, follow, recado e depoimento viram upsert
      idempotente por uri: a escrita otimista e o eco do stream são o
      mesmo evento chegando duas vezes (spec 8.2). blogroll e
      canto.config são records únicos (`literal:self`), upsert por dono;
    * deletes removem a linha do índice (hard delete, como o m1 já faz
      pela interface; os tombstones do spec 8.5 entram quando as threads
      de resposta forem renderizadas). delete de canto.config é
      ignorado: sem config, o canto fica no padrão;
    * eventos `identity` atualizam a tabela de identidades.

  O cursor (`time_us` do último evento) é persistido na tabela
  `firehose_cursor` a cada `@persist_interval` ms e no terminate, para o
  boot retomar de onde parou. Entre boots, o próprio
  `ProtoRune.Jetstream` reconecta resumindo do último cursor entregue.

  Opções de `start_link/1`: `:relay` (padrão
  `wss://jetstream2.us-east.bsky.network`), `:name` e `:jetstream`
  (`false` não conecta, para testes que alimentam eventos com `send/2`).
  """

  use GenServer

  import Ecto.Query

  alias ProtoRune.Jetstream
  alias ProtoRune.Jetstream.Event
  alias Quintal.Blogroll
  alias Quintal.Blogrolls
  alias Quintal.Cantos
  alias Quintal.Depoimentos
  alias Quintal.FirehoseCursor
  alias Quintal.Follows
  alias Quintal.Identidade
  alias Quintal.Prosas
  alias Quintal.Recados
  alias Quintal.Repo

  require Logger

  @default_relay "wss://jetstream2.us-east.bsky.network"
  @persist_interval 5_000
  @cursor_row_id 1

  @follow "place.quintal.graph.follow"
  @prosa "place.quintal.feed.prosa"
  @recado "place.quintal.canto.recado"
  @depoimento "place.quintal.canto.depoimento"
  @blogroll "place.quintal.canto.blogroll"
  @canto_config "place.quintal.canto.config"

  @collections [@prosa, @follow, @recado, @depoimento, @blogroll, @canto_config]

  # 2024-01-01 em microssegundos: abaixo disso o cursor persistido é um
  # seq do firehose antigo, sem sentido como time_us — retoma do live
  @min_time_us 1_704_067_200_000_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl true
  def init(opts) do
    cursor = load_cursor()

    jetstream =
      if Keyword.get(opts, :jetstream, true) do
        relay = Keyword.get(opts, :relay, @default_relay)

        {:ok, pid} =
          Jetstream.start_link(
            handler: self(),
            relay: relay,
            cursor: cursor,
            wanted_collections: @collections
          )

        pid
      end

    schedule_persist()
    {:ok, %{jetstream: jetstream, last_cursor: cursor}}
  end

  @impl true
  def handle_info({:jetstream, %Event{} = event}, state) do
    process(event)
    {:noreply, %{state | last_cursor: event.time_us || state.last_cursor}}
  end

  def handle_info(:persist_cursor, state) do
    persist_cursor(state.last_cursor)
    schedule_persist()
    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state), do: persist_cursor(state.last_cursor)

  defp process(%Event{type: :commit} = event) do
    uri = "at://#{event.did}/#{event.collection}/#{event.rkey}"

    case {event.collection, event.operation} do
      {@prosa, :delete} ->
        Prosas.desindexar(uri)

      {@follow, :delete} ->
        Follows.desindexar(uri)

      {@recado, :delete} ->
        Recados.desindexar(uri)

      {@depoimento, :delete} ->
        Depoimentos.desindexar(uri)

      {@blogroll, :delete} ->
        Repo.delete_all(from b in Blogroll, where: b.dono_did == ^event.did)

      # delete de canto.config: sem config o canto fica no padrão, nada a fazer
      {@canto_config, :delete} ->
        :ok

      {@prosa, _escrita} ->
        with %{} = record <- record(event), do: Prosas.indexar(event.did, %{uri: uri, cid: event.cid, value: record})

      {@follow, _escrita} ->
        with %{} = record <- record(event), do: Follows.indexar(event.did, %{uri: uri, value: record})

      {@recado, _escrita} ->
        with %{} = record <- record(event), do: Recados.indexar(event.did, %{uri: uri, value: record})

      {@depoimento, _escrita} ->
        with %{} = record <- record(event), do: Depoimentos.indexar(event.did, %{uri: uri, value: record})

      {@blogroll, _escrita} ->
        with %{} = record <- record(event), do: Blogrolls.indexar(event.did, %{value: record})

      {@canto_config, _escrita} ->
        with %{} = record <- record(event), do: Cantos.indexar(event.did, %{value: record})

      {_outra_colecao, _qualquer} ->
        :ok
    end

    :ok
  end

  defp process(%Event{type: :identity, did: did, payload: payload}) when is_binary(did) do
    case payload do
      %{"identity" => %{"handle" => handle}} when is_binary(handle) ->
        Repo.update_all(
          from(i in Identidade, where: i.did == ^did),
          set: [handle: handle, atualizado_em: DateTime.utc_now()]
        )

      _sem_handle ->
        :ok
    end
  end

  defp process(_event), do: :ok

  defp record(%Event{record: nil} = event) do
    Logger.warning(
      "[#{__MODULE__}] record ausente no commit de #{event.did} (#{event.collection}/#{event.rkey})"
    )

    nil
  end

  defp record(%Event{record: record}), do: record

  defp load_cursor do
    case Repo.one(from c in FirehoseCursor, where: c.id == @cursor_row_id, select: c.cursor) do
      cursor when is_integer(cursor) and cursor >= @min_time_us -> cursor
      _legado_ou_nulo -> nil
    end
  end

  defp persist_cursor(nil), do: :ok

  defp persist_cursor(cursor) do
    %FirehoseCursor{id: @cursor_row_id, cursor: cursor}
    |> Repo.insert(on_conflict: [set: [cursor: cursor]], conflict_target: :id)
    |> case do
      {:ok, _row} -> :ok
      {:error, reason} -> Logger.warning("[#{__MODULE__}] cursor #{cursor} não persistiu: #{inspect(reason)}")
    end
  end

  defp schedule_persist, do: Process.send_after(self(), :persist_cursor, @persist_interval)
end
