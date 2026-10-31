defmodule QuintalWeb.FaqLiveTest do
  use QuintalWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "apresenta o quintal e o axô", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/faq")

    assert html =~ "sobre o quintal"
    assert html =~ "quem é o axô?"
  end

  test "explica o vocabulário da vizinhança", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/faq")

    assert html =~ "canto"
    assert html =~ "prosa"
    assert html =~ "recado"
    assert html =~ "depoimento"
    assert html =~ "cumadi"
    assert html =~ "vizinhança"
    assert html =~ "passear"
    assert html =~ "visitas"
  end

  test "explica os termos técnicos em linguagem simples", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/faq")

    assert html =~ "o que é um pds?"
    assert html =~ "handle e did"
    assert html =~ "oauth"
    assert html =~ "posso ir embora?"
  end

  test "linka a documentação do protocolo", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/faq")

    assert html =~ "atproto.com/specs"
    assert html =~ "atproto.com/guides"
    assert html =~ "quintal.place/lexicons"
    assert html =~ "https://github.com/zoedsoupe/quintal"
  end

  test "perguntas têm âncoras estáveis e o link aponta para o índice de lexicons", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/faq")

    assert html =~ ~s(id="atproto")
    assert html =~ ~s(id="detalhe-tecnico")
    assert html =~ ~s(href="https://quintal.place/lexicons")
    assert html =~ ~s(class="chrome__topo")
  end
end
