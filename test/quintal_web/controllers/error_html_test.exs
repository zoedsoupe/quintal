defmodule QuintalWeb.ErrorHTMLTest do
  use QuintalWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  test "renders 404.html" do
    html = render_to_string(QuintalWeb.ErrorHTML, "404", "html", [])
    assert html =~ "o axô procurou, procurou... e não achou essa página"
  end

  test "renders 401.html" do
    html = render_to_string(QuintalWeb.ErrorHTML, "401", "html", [])
    assert html =~ "opa, pode entrar não"
  end

  test "renders 500.html" do
    html = render_to_string(QuintalWeb.ErrorHTML, "500", "html", [])
    assert html =~ "ih, algo deu errado. tenta de novo?"
  end
end
