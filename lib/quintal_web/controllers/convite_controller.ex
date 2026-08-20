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
    codigo = canonizar(codigo)

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

  # O código se escreve à mão e se cola de mensageiro: aceita case,
  # espaços, hífens "espertos" (U+2011, em-dash) e invisíveis de colagem
  # (zero-width space), reduzindo tudo à forma canônica "axo-xxxxxxxx".
  defp canonizar(codigo) do
    limpo = codigo |> String.downcase() |> String.replace(~r/[^a-z0-9]/u, "")

    case limpo do
      "axo" <> sufixo when sufixo != "" -> "axo-" <> sufixo
      _ -> limpo
    end
  end
end
