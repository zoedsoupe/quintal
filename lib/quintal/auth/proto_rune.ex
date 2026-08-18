defmodule Quintal.Auth.ProtoRune do
  @moduledoc """
  `Quintal.Auth` implementation backed by proto_rune's AT Protocol OAuth.

  Configuration:

      config :quintal, Quintal.Auth.ProtoRune,
        client_id: "https://quintal.blog.br/oauth/client-metadata.json",
        redirect_uri: "https://quintal.blog.br/oauth/callback",
        scope: "atproto repo:place.quintal.feed.prosa ..."
  """

  @behaviour Quintal.Auth

  alias ProtoRune.Atproto.OAuth
  alias ProtoRune.Atproto.OAuth.Client

  @impl true
  def authorize_url(identifier) when is_binary(identifier) do
    with {:ok, client} <- client(),
         {:ok, url, pending} <- OAuth.authorization_url(client, identifier) do
      {:ok, url, %{client: client, pending: pending}}
    end
  end

  @impl true
  def exchange(%{client: %Client{} = client, pending: pending}, params) when is_map(params) do
    OAuth.exchange_code(client, pending, params)
  end

  def exchange(_pending, _params), do: {:error, :invalid_pending}

  @impl true
  def refresh(%{client: %Client{} = client, session: session}) do
    with {:ok, fresh} <- OAuth.refresh(client, session) do
      {:ok, %{client: client, session: fresh}}
    end
  end

  def refresh(_session), do: {:error, :invalid_session}

  @impl true
  def revoke(%{client: %Client{client_id: client_id}, session: session}) do
    case OAuth.revoke(session, client_id: client_id) do
      {:ok, :revoked} -> :ok
      {:error, _} = error -> error
    end
  end

  def revoke(_session), do: {:error, :invalid_session}

  defp client do
    config = Application.fetch_env!(:quintal, __MODULE__)

    Client.new(
      client_id: Keyword.fetch!(config, :client_id),
      redirect_uri: Keyword.fetch!(config, :redirect_uri),
      scope: Keyword.get(config, :scope, default_scope())
    )
  end

  defp default_scope do
    Enum.join(
      [
        "atproto",
        "repo:place.quintal.feed.prosa",
        "repo:place.quintal.canto.*",
        "repo:place.quintal.graph.follow"
      ],
      " "
    )
  end
end
