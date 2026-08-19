defmodule QuintalWeb.PassearLiveTest do
  use QuintalWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Quintal.Prosas
  alias Quintal.Repo

  setup do
    Repo.insert!(%Quintal.Identidade{
      did: "did:plc:beto",
      handle: "beto.bsky.social",
      pds_url: "https://pds.example",
      atualizado_em: DateTime.utc_now()
    })

    :ok
  end

  test "abre quase vazia, com o axô de lupa e o botão passear", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/passear")

    assert html =~ "o axô acha um canto pra você conhecer"
    assert html =~ "axo-with-glass.png"
    assert html =~ "passear"
  end

  test "passear sorteia uma carta de descoberta", %{conn: conn} do
    {:ok, _} =
      Prosas.indexar("did:plc:beto", %{
        uri: "at://did:plc:beto/place.quintal.feed.prosa/p1",
        cid: "bafy",
        value: %{text: "uma prosa para ser descoberta", created_at: "2026-08-01T10:00:00Z"}
      })

    {:ok, view, _html} = live(conn, "/passear")
    html = view |> element("button", "passear") |> render_click()

    assert html =~ "uma prosa para ser descoberta"
    assert html =~ "beto.bsky.social"
    assert html =~ "visitar esse canto"
    assert html =~ "de novo"
  end

  test "passear com o índice vazio mantém a tela inicial", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/passear")
    html = view |> element("button", "passear") |> render_click()

    assert html =~ "o axô acha um canto pra você conhecer"
  end
end
