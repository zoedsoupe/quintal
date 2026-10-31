defmodule QuintalWeb.CadastroLiveTest do
  use QuintalWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "explica o pds e aponta para os guias", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/cadastro")

    assert html =~ "criar conta"
    assert html =~ "bsky.social"
    assert html =~ "atproto.com/guides/self-hosting"
    assert html =~ "voltar e entrar"
    assert html =~ "class=\"chrome__topo\""
  end

  test "home leva ao convite e a página de convite aponta para o cadastro", %{conn: conn} do
    {:ok, _view, home} = live(conn, "/")
    {:ok, _view, convite} = live(conn, "/convite")

    assert home =~ ~s(href="/convite")
    refute home =~ ~s(href="/cadastro")
    assert convite =~ ~s(href="/cadastro")
  end
end
