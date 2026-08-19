defmodule QuintalWeb.CondutaLiveTest do
  use QuintalWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "mostra as regrinhas de convivência da vizinhança", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/conduta")

    assert html =~ "regrinhas de convivência"
    assert html =~ "o que não cabe aqui"
    assert html =~ "moderação"
    assert html =~ "denunciar"
  end

  test "nomeia a transfobia explicitamente", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/conduta")

    assert html =~ "uma nota sobre transfobia"
    assert html =~ "transfobia aqui não é opinião"
  end
end
