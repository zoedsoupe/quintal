defmodule QuintalWeb.CondutaLiveTest do
  use QuintalWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "mostra as regras mínimas da vizinhança", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/conduta")

    assert html =~ "código de conduta"
    assert html =~ "o esperado"
    assert html =~ "o que não cabe aqui"
    assert html =~ "moderação"
    assert html =~ "denunciar"
  end
end
