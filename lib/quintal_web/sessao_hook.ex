defmodule QuintalWeb.SessaoHook do
  @moduledoc """
  Resolve a sessão atproto a partir da sessão http (`session["quintal_did"]`)
  e deixa em `@sessao` para todas as LiveViews do `live_session :default`.

  `nil` quando a pessoa está deslogada. O struct da sessão vem do
  `Quintal.Auth.impl().current_session/1`, com refresh proativo por
  trás (spec 8.2): a interface nunca pensa em token.

  A variante `:privado` fecha a portaria do alpha nas rotas de conteúdo:
  sem sessão, a pessoa volta para a home em vez de passear pelo quintal.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [redirect: 2]

  def on_mount(:default, _params, session, socket) do
    {:cont, assign(socket, :sessao, sessao(session))}
  end

  def on_mount(:privado, _params, session, socket) do
    case sessao(session) do
      nil -> {:halt, redirect(socket, to: "/")}
      sessao -> {:cont, assign(socket, :sessao, sessao)}
    end
  end

  defp sessao(session) do
    with did when is_binary(did) <- session["quintal_did"],
         {:ok, sessao} <- Quintal.Auth.impl().current_session(did) do
      sessao
    else
      _ -> nil
    end
  end
end
