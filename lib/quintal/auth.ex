defmodule Quintal.Auth do
  @moduledoc """
  AT Protocol OAuth boundary for quintal.

  The flow: `authorize_url/1` starts the authorization (PAR + PKCE + DPoP)
  and returns the URL to redirect the person to, plus an opaque `pending`
  state that must be kept (signed Phoenix session) until the callback.
  `exchange/2` trades the callback params for a session. Sessions are
  indexed by `did` and refresh transparently via `refresh/1`.

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

  @doc "Exchanges callback params for a session."
  @callback exchange(pending(), params :: map()) :: {:ok, session()} | error()

  @doc "Refreshes an expired session."
  @callback refresh(session()) :: {:ok, session()} | error()

  @doc "Revokes the session refresh token (logout)."
  @callback revoke(session()) :: :ok | error()

  @doc "The configured implementation."
  @spec impl() :: module()
  def impl, do: Application.get_env(:quintal, :auth_impl, Quintal.Auth.ProtoRune)
end
