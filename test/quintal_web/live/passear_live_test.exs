defmodule QuintalWeb.PassearLiveTest do
  use QuintalWeb.ConnCase, async: true

  import Mox
  import Phoenix.LiveViewTest

  alias Quintal.Auth.Mock
  alias Quintal.Prosas
  alias Quintal.Repo

  setup :verify_on_exit!

  setup do
    Repo.insert!(%Quintal.Identidade{
      did: "did:plc:beto",
      handle: "beto.bsky.social",
      pds_url: "https://pds.example",
      atualizado_em: DateTime.utc_now()
    })

    stub(Mock, :current_session, fn "did:plc:beto" ->
      {:ok,
       %ProtoRune.Atproto.OAuth.Session{
         did: "did:plc:beto",
         handle: "beto.bsky.social",
         access_token: "token-abc",
         dpop_key: "key",
         dpop_jwk: %{},
         service_url: "https://pds.example"
       }}
    end)

    conn = init_test_session(build_conn(), %{quintal_did: "did:plc:beto"})
    {:ok, conn: conn}
  end

  test "portaria fecha o passear para quem não entrou" do
    conn = get(build_conn(), "/passear")

    assert html_response(conn, 401) =~ "opa, pode entrar não"
  end

  test "abre quase vazia, com o axô de lupa e o botão passear", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/passear")

    assert html =~ "o axô acha um canto pra você conhecer"
    assert html =~ "axo-with-glass.png"
    assert html =~ "passear"
  end

  test "passear sorteia uma carta de descoberta", %{conn: conn} do
    # a prosa sorteada é de outra pessoa: o passear nunca mostra o próprio canto
    Repo.insert!(%Quintal.Identidade{
      did: "did:plc:clara",
      handle: "clara.bsky.social",
      pds_url: "https://pds.example",
      atualizado_em: DateTime.utc_now()
    })

    {:ok, _} =
      Prosas.indexar("did:plc:clara", %{
        uri: "at://did:plc:clara/place.quintal.feed.prosa/p1",
        cid: "bafy",
        value: %{text: "uma prosa para ser descoberta", created_at: "2026-08-01T10:00:00Z"}
      })

    {:ok, view, _html} = live(conn, "/passear")
    html = view |> element("button", "passear") |> render_click()

    assert html =~ "uma prosa para ser descoberta"
    assert html =~ "clara.bsky.social"
    assert html =~ "visitar esse canto"
    assert html =~ "de novo"
  end

  test "passear com o índice vazio mantém a tela inicial", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/passear")
    html = view |> element("button", "passear") |> render_click()

    assert html =~ "o axô acha um canto pra você conhecer"
  end
end
