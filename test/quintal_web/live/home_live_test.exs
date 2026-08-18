defmodule QuintalWeb.HomeLiveTest do
  use QuintalWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "deslogada: sugere entrar com handle atproto", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")

    assert html =~ "uma vizinhança de blogs"
    assert html =~ ~s(action="/oauth/login")
    assert html =~ ~s(name="handle")
  end

  test "logada: visão mínima do app com o vazio do spec", %{conn: conn} do
    conn =
      init_test_session(conn, %{quintal_session: %{session: %{handle: "alice.bsky.social"}}})

    {:ok, _view, html} = live(conn, "/")

    assert html =~ "oi, alice.bsky.social"
    assert html =~ "por aqui ainda tá quieto"
    assert html =~ "/oauth/logout"
  end
end
