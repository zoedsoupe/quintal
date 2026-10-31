defmodule QuintalWeb.SessaoHook do
  @moduledoc """
  Resolve a sessão atproto a partir da sessão http (`session["quintal_did"]`)
  e deixa em `@sessao` para todas as LiveViews do `live_session :quintal`.

  `nil` quando a pessoa está deslogada. O struct da sessão vem do
  `Quintal.Auth.impl().current_session/1`, com refresh proativo por
  trás (spec 8.2): a interface nunca pensa em token.

  A variante `:privado` cobre o caso da sessão expirar no meio da
  navegação: manda a pessoa de volta para a home. A pipeline `:portaria`
  também protege as requisições http das rotas privadas.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3, redirect: 2]

  @privadas [
    QuintalWeb.HomeLive,
    QuintalWeb.BoasVindasLive,
    QuintalWeb.EscreverLive,
    QuintalWeb.VisitasLive,
    QuintalWeb.ContaLive
  ]

  def on_mount(:default, _params, session, socket) do
    {:cont, assign(socket, :sessao, sessao(session))}
  end

  def on_mount(:privado, _params, session, socket) do
    case sessao(session) do
      nil ->
        socket =
          if session["quintal_did"] do
            put_flash(socket, :info, "sua sessão expirou. entre novamente para continuar.")
          else
            socket
          end

        {:halt, redirect(socket, to: "/")}

      sessao ->
        {:cont, assign(socket, :sessao, sessao)}
    end
  end

  def on_mount(:unificado, _params, session, socket) do
    sessao = sessao(session)

    if socket.view in @privadas and is_nil(sessao) do
      socket =
        if session["quintal_did"] do
          put_flash(socket, :info, "sua sessão expirou. entre novamente para continuar.")
        else
          socket
        end

      {:halt, redirect(socket, to: "/")}
    else
      {:cont, assign(socket, :sessao, sessao)}
    end
  end

  defp sessao(session) do
    did = session["quintal_did"] || Application.get_env(:quintal, :dev_identidade)

    with did when is_binary(did) <- did,
         {:ok, sessao} <- Quintal.Auth.impl().current_session(did) do
      sessao
    else
      _ -> nil
    end
  end
end
