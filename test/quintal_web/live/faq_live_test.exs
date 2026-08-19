defmodule QuintalWeb.FaqLiveTest do
  use QuintalWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "explica os termos técnicos em linguagem simples", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/faq")

    assert html =~ "perguntas frequentes"
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
  end
end
