defmodule QuintalWeb.ConviteController do
  @moduledoc """
  A portaria do alpha fechado (spec 6.1; marco m4).

  A tela mora no `ConviteLive`; este controller só recebe o POST do
  código, porque escrever na sessão http é fora do alcance do LiveView.
  Código válido fica guardado na sessão e entra junto no primeiro
  acesso oauth (`OAuthController.callback`); inválido volta para a
  tela com um erro gentil.
  """

  use QuintalWeb, :controller

  def create(conn, %{"codigo" => codigo}) do
    codigo = codigo |> String.trim() |> String.downcase()

    if Quintal.Convites.valido?(codigo) do
      conn
      |> put_session(:convite, codigo)
      |> put_flash(:info, "convite guardado. agora entra com seu handle atproto")
      |> redirect(to: "/")
    else
      conn
      |> put_flash(:error, "esse código já foi usado ou não existe. pede pra quem te convidou?")
      |> redirect(to: "/convite")
    end
  end
end
