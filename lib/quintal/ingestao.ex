defmodule Quintal.Ingestao do
  @moduledoc """
  O consumidor do firehose (spec 8.1 e 9.5; marco m2).

  Assina `com.atproto.sync.subscribeRepos` via `ProtoRune.Firehose`,
  filtra os commits que tocam coleções `place.quintal.*` mais os eventos
  de identidade, e mantém o índice postgres em sincronia:

    * create/update de prosa e follow viram upsert idempotente por uri:
      a escrita otimista e o eco do firehose são o mesmo evento chegando
      duas vezes (spec 8.2);
    * deletes removem a linha do índice (hard delete, como o m1 já faz
      pela interface; os tombstones do spec 8.5 entram quando as threads
      de resposta forem renderizadas);
    * eventos `identity` e `handle` atualizam a tabela de identidades.

  O cursor é persistido na tabela `firehose_cursor` a cada
  `@persist_interval` ms e no terminate, para o boot retomar de onde
  parou. Entre boots, o próprio `ProtoRune.Firehose` reconecta
  resumindo do último seq entregue.

  Opções de `start_link/1`: `:relay` (padrão `wss://bsky.network`),
  `:name` e `:firehose` (`false` não conecta, para testes que alimentam
  eventos com `send/2`).
  """

  use GenServer

  import Ecto.Query

  alias ProtoRune.Firehose
  alias ProtoRune.Firehose.Event
  alias Quintal.FirehoseCursor
  alias Quintal.Follows
  alias Quintal.Identidade
  alias Quintal.Prosas
  alias Quintal.Repo

  require Logger

  @default_relay "wss://bsky.network"
  @persist_interval 5_000
  @cursor_row_id 1

  @follow "place.quintal.graph.follow"
  @prosa "place.quintal.feed.prosa"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl true
  def init(opts) do
    cursor = load_cursor()

    firehose =
      if Keyword.get(opts, :firehose, true) do
        relay = Keyword.get(opts, :relay, @default_relay)
        {:ok, pid} = Firehose.start_link(handler: self(), relay: relay, cursor: cursor)
        pid
      end

    schedule_persist()
    {:ok, %{firehose: firehose, last_seq: cursor}}
  end

  @impl true
  def handle_info({:firehose, %Event{} = event}, state) do
    process(event)
    {:noreply, %{state | last_seq: event.seq || state.last_seq}}
  end

  def handle_info(:persist_cursor, state) do
    persist_cursor(state.last_seq)
    schedule_persist()
    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state), do: persist_cursor(state.last_seq)

  defp process(%Event{type: :commit, repo: repo} = event) when is_binary(repo) do
    if Event.collection?(event, "place.quintal") do
      Enum.each(event.ops, &op(event, &1))
    end
  end

  defp process(%Event{type: type, repo: did, payload: payload}) when type in [:identity, :handle] and is_binary(did) do
    case payload do
      %{"handle" => handle} when is_binary(handle) ->
        Repo.update_all(
          from(i in Identidade, where: i.did == ^did),
          set: [handle: handle, atualizado_em: DateTime.utc_now()]
        )

      _sem_handle ->
        :ok
    end
  end

  defp process(_event), do: :ok

  defp op(%Event{repo: repo} = event, %{action: action, path: path, cid: cid}) do
    uri = "at://#{repo}/#{path}"

    case String.split(path, "/", parts: 2) do
      [@prosa, _rkey] -> prosa(event, action, uri, cid)
      [@follow, _rkey] -> follow(event, action, uri, cid)
      _outra_colecao -> :ok
    end
  end

  defp prosa(event, action, uri, cid) when action in [:create, :update] do
    with %{} = value <- bloco(event, cid) do
      Prosas.indexar(event.repo, %{uri: uri, cid: to_string(cid), value: value})
    end

    :ok
  end

  defp prosa(_event, :delete, uri, _cid), do: Prosas.desindexar(uri)

  defp follow(event, action, uri, cid) when action in [:create, :update] do
    with %{} = value <- bloco(event, cid) do
      Follows.indexar(event.repo, %{uri: uri, value: value})
    end

    :ok
  end

  defp follow(_event, :delete, uri, _cid), do: Follows.desindexar(uri)

  defp bloco(_event, nil), do: nil

  defp bloco(event, cid) do
    case Map.get(event.blocks, to_string(cid)) do
      nil ->
        Logger.warning("[#{__MODULE__}] bloco #{cid} ausente no commit de #{event.repo}")
        nil

      value ->
        value
    end
  end

  defp load_cursor do
    Repo.one(from c in FirehoseCursor, where: c.id == @cursor_row_id, select: c.cursor)
  end

  defp persist_cursor(nil), do: :ok

  defp persist_cursor(seq) do
    %FirehoseCursor{id: @cursor_row_id, cursor: seq}
    |> Repo.insert(on_conflict: [set: [cursor: seq]], conflict_target: :id)
    |> case do
      {:ok, _row} -> :ok
      {:error, reason} -> Logger.warning("[#{__MODULE__}] cursor #{seq} não persistiu: #{inspect(reason)}")
    end
  end

  defp schedule_persist, do: Process.send_after(self(), :persist_cursor, @persist_interval)
end
