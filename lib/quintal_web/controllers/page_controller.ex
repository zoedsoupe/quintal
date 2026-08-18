defmodule QuintalWeb.PageController do
  @moduledoc """
  Página raiz mínima enquanto o canto não existe. Serve de destino do
  redirect do callback OAuth.
  """

  use QuintalWeb, :controller

  def home(conn, _params) do
    text(conn, "quintal")
  end
end
