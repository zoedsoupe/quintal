defmodule QuintalWeb.PublicPagesTest do
  use QuintalWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Quintal.Repo

  defp identidade(did, handle) do
    Repo.insert!(%Quintal.Identidade{
      did: did,
      handle: handle,
      pds_url: "https://pds.example",
      atualizado_em: DateTime.utc_now()
    })
  end

  test "chrome público permite passear e entrar", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/passear")

    assert html =~ ~s(aria-label="navegação principal")
    assert html =~ ">passear</a>"
    assert html =~ ">entrar</a>"
  end

  test "canto anônimo vazio convida a deixar depoimento", %{conn: conn} do
    identidade("did:plc:beto", "beto.bsky.social")

    {:ok, _view, html} = live(conn, "/canto/beto.bsky.social")

    assert html =~ "depoimentos"
    assert html =~ "esse canto ainda não tem depoimentos"
    assert html =~ "entre para deixar um depoimento"
    refute html =~ "entre para prosear"
  end

  test "rotas públicas não apontam estados vazios para páginas privadas", %{conn: conn} do
    {:ok, _view, canto_html} = live(conn, "/canto/nao-existe.bsky.social")
    {:ok, _view, prosa_html} = live(conn, "/canto/nao-existe.bsky.social/prosa/abc")

    assert canto_html =~ "passear pelo quintal"
    assert canto_html =~ "class=\"sr-only\">canto não encontrado</h1>"
    assert prosa_html =~ "passear pelo quintal"
    refute canto_html =~ "/inicio"
    refute prosa_html =~ "/inicio"
  end
end
