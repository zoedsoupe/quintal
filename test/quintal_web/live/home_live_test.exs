defmodule QuintalWeb.HomeLiveTest do
  use QuintalWeb.ConnCase, async: true

  import Mox
  import Phoenix.LiveViewTest

  alias Quintal.Auth.Mock

  setup :verify_on_exit!

  test "deslogada: sugere entrar com handle atproto", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")

    assert html =~ "uma vizinhança de blogs"
    assert html =~ ~s(action="/oauth/login")
    assert html =~ ~s(name="handle")
  end

  test "logada: visão mínima do app com o vazio do spec", %{conn: conn} do
    stub(Mock, :current_session, fn "did:plc:alice" ->
      {:ok, %{did: "did:plc:alice", handle: "alice.bsky.social"}}
    end)

    conn = init_test_session(conn, %{quintal_did: "did:plc:alice"})

    {:ok, _view, html} = live(conn, "/")

    assert html =~ "oi, alice.bsky.social"
    assert html =~ "por aqui ainda tá quieto"
    assert html =~ "/oauth/logout"
  end

  test "sessão inválida cai no estado deslogado", %{conn: conn} do
    stub(Mock, :current_session, fn "did:plc:ninguem" -> {:error, :not_found} end)

    conn = init_test_session(conn, %{quintal_did: "did:plc:ninguem"})

    {:ok, _view, html} = live(conn, "/")

    assert html =~ "uma vizinhança de blogs"
  end
end
