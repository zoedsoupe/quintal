defmodule QuintalWeb.PortariaPlug do
  @moduledoc """
  A portaria fechada do alpha (spec 6.1) como guarda de pipeline nas
  rotas de conteúdo: sem `quintal_did` na sessão, a pessoa recebe o 401
  da casa com status, em vez de ser jogada de volta para a home sem
  explicação.
  """

  @behaviour Plug

  import Phoenix.Controller
  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    if autenticado?(conn) do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> put_root_layout(false)
      |> put_layout(false)
      |> put_view(html: QuintalWeb.ErrorHTML)
      |> render(:"401")
      |> halt()
    end
  end

  # em dev com uma identidade fixa (revisão, debug) a portaria deixa
  # passar; o SessaoHook resolve a sessão sintética do Quintal.Auth.Dev
  defp autenticado?(conn) do
    get_session(conn, :quintal_did) != nil or Application.get_env(:quintal, :dev_identidade) != nil
  end
end
