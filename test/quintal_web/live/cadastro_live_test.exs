defmodule QuintalWeb.CadastroLiveTest do
  use QuintalWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "explica o pds e aponta para os guias", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/cadastro")

    assert html =~ "criar conta"
    assert html =~ "bsky.social"
    assert html =~ "atproto.com/guides/self-hosting"
    assert html =~ "voltar e entrar"
  end

  test "home aponta para o cadastro", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")

    assert html =~ "/cadastro"
    assert html =~ "não tenho conta ainda"
  end
end
