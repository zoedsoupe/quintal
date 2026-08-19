defmodule QuintalWeb.OAuthController do
  @moduledoc """
  Endpoints do fluxo OAuth atproto.

  `client_metadata` serve o documento de metadados do cliente público:
  o `client_id` do quintal é a URL desse endpoint, e o authorization
  server do pds busca aqui redirect_uri, scope e política de DPoP.

  `callback` recebe o retorno do authorization server, troca o code por
  uma sessão via `Quintal.Auth` e guarda só o did no cookie assinado:
  os tokens vivem cifrados na tabela `sessoes`, com refresh proativo.
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
         {:ok, did} <- Quintal.Auth.impl().open_session(pending, params),
         :ok <- portaria(conn, did) do
      bootstrap_async(did)

      conn
      |> delete_session(:oauth_pending)
      |> delete_session(:convite)
      |> put_session(:quintal_did, did)
      |> redirect(to: "/")
    else
      {:portaria, conn} ->
        conn

      _ ->
        conn
        |> put_status(:unauthorized)
        |> put_view(html: QuintalWeb.ErrorHTML)
        |> render("401.html")
        |> halt()
    end
  end

  # O gate do alpha fechado (spec 6.1): quem já mora no quintal entra
  # direto; cara nova precisa de um código válido guardado na sessão
  # pela tela de convite. Sem código, a sessão oauth recém-aberta é
  # revogada na hora e a pessoa volta para a portaria.
  defp portaria(conn, did) do
    cond do
      Quintal.Convites.entrou?(did) ->
        :ok

      codigo = get_session(conn, :convite) ->
        case Quintal.Convites.usar(codigo, did) do
          :ok -> :ok
          {:error, :invalido} -> recusar(conn, did)
        end

      true ->
        recusar(conn, did)
    end
  end

  defp recusar(conn, did) do
    Quintal.Auth.impl().logout(did)

    {:portaria,
     conn
     |> delete_session(:oauth_pending)
     |> put_flash(:error, "esse código já foi usado ou não existe. pede pra quem te convidou?")
     |> redirect(to: "/convite")}
  end

  # Cria o canto.config e indexa o histórico (spec 8.2, fluxo 1), fora
  # do caminho do request: o login nunca espera nem quebra por causa
  # do bootstrap.
  defp bootstrap_async(did) do
    with {:ok, session} <- Quintal.Auth.impl().current_session(did) do
      Task.Supervisor.start_child(Quintal.TaskSupervisor, Quintal.Bootstrap, :run, [session])
    end

    :ok
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
    if did = get_session(conn, :quintal_did) do
      Quintal.Auth.impl().logout(did)
    end

    conn
    |> clear_session()
    |> redirect(to: "/")
  end
end
