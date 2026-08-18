defmodule QuintalWeb.OAuthController do
  @moduledoc """
  Endpoints do fluxo OAuth atproto.

  `client_metadata` serve o documento de metadados do cliente público:
  o `client_id` do quintal é a URL desse endpoint, e o authorization
  server do pds busca aqui redirect_uri, scope e política de DPoP.

  `callback` recebe o retorno do authorization server, troca o code por
  uma sessão via `Quintal.Auth` e guarda a sessão no cookie assinado.
  """

  use QuintalWeb, :controller

  def client_metadata(conn, _params) do
    config = Application.fetch_env!(:quintal, Quintal.Auth.ProtoRune)
    client_id = Keyword.fetch!(config, :client_id)

    json(conn, %{
      client_id: client_id,
      client_name: "quintal",
      client_uri: client_id |> URI.merge("/") |> URI.to_string(),
      redirect_uris: [Keyword.fetch!(config, :redirect_uri)],
      scope: Keyword.fetch!(config, :scope),
      grant_types: ["authorization_code", "refresh_token"],
      response_types: ["code"],
      token_endpoint_auth_method: "none",
      application_type: "web",
      dpop_bound_access_tokens: true
    })
  end

  def callback(conn, params) do
    with pending when not is_nil(pending) <- get_session(conn, :oauth_pending),
         {:ok, session} <- Quintal.Auth.impl().exchange(pending, params) do
      conn
      |> delete_session(:oauth_pending)
      |> put_session(:quintal_session, session)
      |> redirect(to: "/")
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> text("ih, algo deu errado. tenta de novo?")
    end
  end

  def login(conn, %{"handle" => handle}) do
    case Quintal.Auth.impl().authorize_url(handle) do
      {:ok, url, pending} ->
        conn
        |> put_session(:oauth_pending, pending)
        |> redirect(external: url)

      {:error, _} ->
        conn
        |> put_flash(:error, "não achei essa conta. confere o handle?")
        |> redirect(to: "/")
    end
  end

  def logout(conn, _params) do
    if sessao = get_session(conn, :quintal_session) do
      Quintal.Auth.impl().revoke(sessao)
    end

    conn
    |> clear_session()
    |> redirect(to: "/")
  end
end
