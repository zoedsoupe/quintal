defmodule QuintalWeb.ContaController do
  @moduledoc """
  O download da exportação (spec 5.1, feature 8): a página de conta
  aponta aqui e o zip sai montado na hora a partir do índice local.

  Portaria fechada como o resto do conteúdo: a pipeline `:portaria`
  responde 401 antes de chegar aqui quando não há sessão.
  """

  use QuintalWeb, :controller

  # rota protegida pela pipeline :portaria (spec 6.1)
  def exportar(conn, _params) do
    did = get_session(conn, :quintal_did)
    {:ok, zip} = Quintal.Exportar.zip(did)
    data = Date.utc_today() |> Date.to_string() |> String.replace("-", "")

    send_download(conn, {:binary, zip}, filename: "quintal-#{data}.zip")
  end
end
