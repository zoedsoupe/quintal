defmodule Quintal.Auth do
  @moduledoc """
  AT Protocol OAuth boundary for quintal.

  The flow: `authorize_url/1` starts the authorization (PAR + PKCE + DPoP)
  and returns the URL to redirect the person to, plus an opaque `pending`
  state that must be kept (signed Phoenix session) until the callback.
  `open_session/2` trades the callback params for a session, persists it
  encrypted in the `sessoes` table and starts a session manager that
  refreshes the tokens proactively. From there the browser cookie carries
  only the `did`, and `current_session/1` resolves it to a live session.

  Scope is restricted to the `place.quintal.*` collections, never broad
  atproto access, never Bluesky collections.
  """

  @typedoc "Opaque authorization flow state between redirect and callback."
  @type pending :: term()

  @typedoc "Opaque authenticated session, indexed by `did`."
  @type session :: term()

  @type error :: {:error, term()}

  @doc "Starts the flow for a handle or DID. Returns the URL to redirect to and the pending state."
  @callback authorize_url(identifier :: String.t()) :: {:ok, String.t(), pending()} | error()

  @doc "Exchanges callback params for a session, persists it and starts its manager. Returns the did."
  @callback open_session(pending(), params :: map()) :: {:ok, did :: String.t()} | error()

  @doc "Resolves a did to a live session, restoring from the store when no manager is running."
  @callback current_session(did :: String.t()) :: {:ok, session()} | error()

  @doc "Revokes the tokens, deletes the stored session and stops the manager."
  @callback logout(did :: String.t()) :: :ok

  @doc "The configured implementation."
  @spec impl() :: module()
  def impl, do: Application.get_env(:quintal, :auth_impl, Quintal.Auth.ProtoRune)

  @doc "The 32-byte key that encrypts sessions at rest."
  @spec key() :: <<_::256>>
  def key, do: Application.fetch_env!(:quintal, :session_key)

  @doc "The `ProtoRune.Security.TokenStore` backend for persisted sessions."
  @spec store() :: ProtoRune.Security.TokenStore.backend()
  def store, do: {Quintal.Auth.TokenStore, []}
end
