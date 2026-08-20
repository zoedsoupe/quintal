defmodule QuintalWeb.LexiconsController do
  @moduledoc """
  Visão humana dos lexicons `place.quintal.*`, servida em
  `quintal.place/lexicons`. Lê os mesmos arquivos JSON servidos crus
  em `/lexicons/:nsid.json` e usados pela validação: fonte única,
  nada de schema duplicado (spec 9.4). Embutidos em tempo de
  compilação: os lexicons só mudam junto com um deploy.
  """

  use QuintalWeb, :controller

  plug :put_layout, false

  @lexicon_paths Path.wildcard(Path.join([Application.app_dir(:quintal, "priv"), "static", "lexicons", "*.json"]))

  for path <- @lexicon_paths do
    @external_resource path
  end

  @lexicons @lexicon_paths
            |> Enum.map(fn path -> JSON.decode!(File.read!(path)) end)
            |> Enum.sort_by(& &1["id"])

  def index(conn, _params) do
    render(conn, :index, lexicons: @lexicons, page_title: "os lexicons")
  end

  def show(conn, %{"nsid" => nsid}) do
    case Enum.find(@lexicons, &(&1["id"] == nsid)) do
      nil ->
        conn
        |> put_status(:not_found)
        |> put_view(html: QuintalWeb.ErrorHTML)
        |> render(:"404")
        |> halt()

      lexicon ->
        render(conn, :show, lexicon: lexicon, page_title: nsid)
    end
  end
end
