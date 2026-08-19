defmodule QuintalWeb.SessaoHook do
  @moduledoc """
  Resolve a sessão atproto a partir da sessão http (`session["quintal_did"]`)
  e deixa em `@sessao` para todas as LiveViews do `live_session :default`.

  `nil` quando a pessoa está deslogada. O struct da sessão vem do
  `Quintal.Auth.impl().current_session/1`, com refresh proativo por
  trás (spec 8.2): a interface nunca pensa em token.
  """

  import Phoenix.Component, only: [assign: 3]

  def on_mount(:default, _params, session, socket) do
    sessao =
      with did when is_binary(did) <- session["quintal_did"],
           {:ok, sessao} <- Quintal.Auth.impl().current_session(did) do
        sessao
      else
        _ -> nil
      end

    {:cont, assign(socket, :sessao, sessao)}
  end
end
