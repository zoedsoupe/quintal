defmodule QuintalWeb.LexiconsControllerTest do
  use QuintalWeb.ConnCase, async: true

  test "GET /lexicons lista todos os lexicons" do
    html =
      :get
      |> build_conn("http://quintal.place/lexicons")
      |> get("/lexicons")
      |> html_response(200)

    assert html =~ "os lexicons do quintal"
    assert html =~ "place.quintal.feed.prosa"
    assert html =~ "place.quintal.richtext.facet"
    assert html =~ "place.quintal.canto.config"
    assert html =~ "json cru"
  end

  test "GET /lexicons/:nsid mostra um lexicon" do
    html =
      :get
      |> build_conn("http://quintal.place/lexicons/place.quintal.feed.prosa")
      |> get("/lexicons/place.quintal.feed.prosa")
      |> html_response(200)

    assert html =~ "place.quintal.feed.prosa"
    assert html =~ "chave tid"
    assert html =~ "replyRef"
    assert html =~ "todos os lexicons"
  end

  test "GET /lexicons/:nsid desconhecido responde 404" do
    conn =
      :get
      |> build_conn("http://quintal.place/lexicons/place.quintal.nao.existe")
      |> get("/lexicons/place.quintal.nao.existe")

    assert html_response(conn, 404)
  end

  test "host do app não serve a documentação" do
    conn =
      :get
      |> build_conn("http://quintal.blog.br/lexicons")
      |> get("/lexicons")

    assert html_response(conn, 404)
  end
end
