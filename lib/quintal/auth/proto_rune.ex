defmodule Quintal.Auth.ProtoRune do
  @moduledoc """
  `Quintal.Auth` implementation backed by proto_rune's AT Protocol OAuth.

  After the code exchange the session is persisted encrypted in the
  `sessoes` table (via `Quintal.Auth.TokenStore`) and a
  `ProtoRune.Atproto.OAuth.SessionManager` starts under
  `Quintal.Auth.SessionSupervisor`, refreshing the tokens proactively
  and persisting each rotation. Managers run with `restart: :temporary`:
  a crashed manager is rebuilt from the store by `current_session/1` or
  by `restore_all/0` at boot, never restarted with stale tokens.

  Configuration:

      config :quintal, Quintal.Auth.ProtoRune,
        client_id: "https://quintal.blog.br/oauth/client-metadata.json",
        redirect_uri: "https://quintal.blog.br/oauth/callback",
        scope: "atproto repo:place.quintal.feed.prosa ..."

  Plus `config :quintal, :session_key`, the 32-byte encryption key.
  """

  @behaviour Quintal.Auth

  alias ProtoRune.Atproto.OAuth
  alias ProtoRune.Atproto.OAuth.Client
  alias ProtoRune.Atproto.OAuth.Session
  alias ProtoRune.Atproto.OAuth.SessionManager
  alias ProtoRune.Security.Crypto
  alias Quintal.Auth.SessionRegistry
  alias Quintal.Auth.TokenStore

  require Logger

  @impl true
  def authorize_url(identifier) when is_binary(identifier) do
    with {:ok, client} <- client(),
         {:ok, url, pending} <- OAuth.authorization_url(client, identifier) do
      {:ok, url, %{client: client, pending: pending}}
    end
  end

  @impl true
  def open_session(%{client: %Client{} = client, pending: pending}, params) when is_map(params) do
    with {:ok, session} <- OAuth.exchange_code(client, pending, params),
         :ok <- persist(session),
         {:ok, _pid} <- start_manager(client, session) do
      {:ok, session.did}
    end
  end

  def open_session(_pending, _params), do: {:error, :invalid_pending}

  @impl true
  def current_session(did) when is_binary(did) do
    case manager_pid(did) do
      {:ok, pid} -> {:ok, SessionManager.session(pid)}
      :error -> restore_session(did)
    end
  catch
    :exit, _reason -> restore_session(did)
  end

  @impl true
  def logout(did) when is_binary(did) do
    case manager_pid(did) do
      {:ok, pid} -> SessionManager.logout(pid)
      :error -> TokenStore.delete(did, [])
    end
  catch
    :exit, _reason -> TokenStore.delete(did, [])
  end

  @doc """
  Restores every persisted session under a fresh manager. Runs once at
  boot; per-session failures are logged and skipped, so one corrupted
  blob never blocks the others.
  """
  @spec restore_all() :: :ok
  def restore_all do
    for did <- TokenStore.all() do
      case restore_session(did) do
        {:ok, _session} ->
          :ok

        {:error, reason} ->
          Logger.warning("[#{__MODULE__}] failed to restore session for #{did}: #{inspect(reason)}")
      end
    end

    :ok
  end

  defp restore_session(did) do
    with {:ok, session} <- load(did),
         {:ok, client} <- client(),
         {:ok, pid} <- start_manager(client, session) do
      {:ok, SessionManager.session(pid)}
    end
  catch
    :exit, _reason ->
      TokenStore.delete(did, [])
      {:error, :session_expired}
  end

  defp start_manager(client, session) do
    opts = [
      session: session,
      client: client,
      store: Quintal.Auth.store(),
      key: Quintal.Auth.key(),
      registry: SessionRegistry
    ]

    spec = %{
      id: SessionManager,
      start: {SessionManager, :start_link, [opts]},
      restart: :temporary
    }

    case DynamicSupervisor.start_child(Quintal.Auth.SessionSupervisor, spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end

  defp manager_pid(did) do
    case Registry.lookup(SessionRegistry, did) do
      [{pid, _value}] -> {:ok, pid}
      [] -> :error
    end
  end

  # `ProtoRune.Security.save_session/load_session` pattern match on the
  # app-password session struct, so OAuth sessions go through `Crypto`
  # directly. The payload is term_to_binary under AES-256-GCM, same as
  # the SessionManager persists on every refresh.
  defp persist(%Session{did: did} = session) do
    with {:ok, blob} <- Crypto.encrypt(:erlang.term_to_binary(session), Quintal.Auth.key()) do
      TokenStore.put(did, blob, [])
    end
  end

  defp load(did) do
    with {:ok, blob} <- TokenStore.fetch(did, []),
         {:ok, plaintext} <- Crypto.decrypt(blob, Quintal.Auth.key()) do
      case :erlang.binary_to_term(plaintext) do
        %Session{} = session -> {:ok, session}
        _other -> {:error, :invalid_session}
      end
    end
  end

  defp client do
    config = Application.fetch_env!(:quintal, __MODULE__)

    Client.new(
      client_id: Keyword.fetch!(config, :client_id),
      redirect_uri: Keyword.fetch!(config, :redirect_uri),
      scope: Keyword.fetch!(config, :scope)
    )
  end
end
