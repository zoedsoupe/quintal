defmodule QuintalWeb.ConviteFlowTest do
  use QuintalWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Quintal.Convites

  test "GET /convite mostra a portaria com o axô", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/convite")

    assert html =~ "o quintal é pequeno de propósito. você foi convidade."
    assert html =~ "axo-front-gretting.png"
  end

  test "POST /convite com código válido guarda na sessão e manda pro login", %{conn: conn} do
    {:ok, convite} = Convites.gerar("admin")

    conn = post(conn, "/convite", %{"codigo" => "  #{String.upcase(convite.codigo)} "})

    assert redirected_to(conn) == "/"
    assert get_session(conn, :convite) == convite.codigo
  end

  test "POST /convite com código inválido volta com erro gentil", %{conn: conn} do
    conn = post(conn, "/convite", %{"codigo" => "axo-zzzz"})

    assert redirected_to(conn) == "/convite"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "já foi usado ou não existe"
    refute get_session(conn, :convite)
  end

  test "POST /convite com código já usado volta com erro", %{conn: conn} do
    {:ok, convite} = Convites.gerar("admin")
    :ok = Convites.usar(convite.codigo, "did:plc:alguem")

    conn = post(conn, "/convite", %{"codigo" => convite.codigo})

    assert redirected_to(conn) == "/convite"
    refute get_session(conn, :convite)
  end
end
