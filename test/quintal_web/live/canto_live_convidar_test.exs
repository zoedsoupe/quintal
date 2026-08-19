defmodule QuintalWeb.CantoLiveConvidarTest do
  use QuintalWeb.ConnCase, async: true

  import Mox
  import Phoenix.LiveViewTest

  alias Quintal.Auth.Mock
  alias Quintal.Convites
  alias Quintal.Repo

  setup :verify_on_exit!

  setup do
    Repo.insert!(%Quintal.Identidade{
      did: "did:plc:alice",
      handle: "alice.bsky.social",
      pds_url: "https://pds.example",
      atualizado_em: DateTime.utc_now()
    })

    stub(Mock, :current_session, fn "did:plc:alice" ->
      {:ok,
       %ProtoRune.Atproto.OAuth.Session{
         did: "did:plc:alice",
         handle: "alice.bsky.social",
         access_token: "token-abc",
         dpop_key: "key",
         dpop_jwk: %{},
         service_url: "https://pds.example"
       }}
    end)

    conn = init_test_session(build_conn(), %{quintal_did: "did:plc:alice"})
    {:ok, conn: conn}
  end

  test "dono vê a seção convidar com a cota cheia", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/canto/alice.bsky.social")

    assert html =~ "convidar"
    assert html =~ "você ainda pode chamar 5 pessoas pro quintal"
    assert html =~ "gerar um convite"
  end

  test "gerar um convite mostra o código na lista", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/canto/alice.bsky.social")

    html = view |> element("button", "gerar um convite") |> render_click()

    assert html =~ ~r/axo-[a-z2-9]{4}/
  end

  test "cota esgotada mostra aviso e esconde o botão de gerar", %{conn: conn} do
    for i <- 1..5 do
      {:ok, convite} = Convites.gerar("did:plc:alice")
      :ok = Convites.usar(convite.codigo, "did:plc:convidada#{i}")
    end

    {:ok, _view, html} = live(conn, "/canto/alice.bsky.social")

    assert html =~ "sua cota de convites acabou por enquanto"
    refute html =~ "gerar um convite"
  end
end
