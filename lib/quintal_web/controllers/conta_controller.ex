defmodule QuintalWeb.ContaController do
  @moduledoc """
  O download da exportação (spec 5.1, feature 8): a página de conta
  aponta aqui e o zip sai montado na hora a partir do índice local.

  Portaria fechada como o resto do conteúdo: sem `quintal_did` na
  sessão, a pessoa volta para a home.
  """

  use QuintalWeb, :controller

  def exportar(conn, _params) do
    case get_session(conn, :quintal_did) do
      nil ->
        redirect(conn, to: "/")

      did ->
        {:ok, zip} = Quintal.Exportar.zip(did)
        data = Date.utc_today() |> Date.to_string() |> String.replace("-", "")

        send_download(conn, {:binary, zip}, filename: "quintal-#{data}.zip")
    end
  end
end
