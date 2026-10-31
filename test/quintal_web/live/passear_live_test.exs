defmodule QuintalWeb.PassearLiveTest do
  use QuintalWeb.ConnCase, async: true

  import Mox
  import Phoenix.LiveViewTest

  alias Quintal.Auth.Mock
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

  test "passear abre para quem ainda não entrou" do
    {:ok, _view, html} = live(build_conn(), "/passear")

    assert html =~ "o axô acha um canto pra você conhecer"
  end

  test "abre quase vazia, com o axô de lupa e o botão passear", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/passear")

    assert html =~ "o axô acha um canto pra você conhecer"
    assert html =~ "axo-with-glass.png"
    assert html =~ "passear"
  end

  test "passear mostra o canto inteiro, mesmo sem prosas", %{conn: conn} do
    Repo.insert!(%Quintal.Identidade{
      did: "did:plc:clara",
      handle: "clara.bsky.social",
      pds_url: "https://pds.example",
      atualizado_em: DateTime.utc_now()
    })

    Repo.insert!(%Quintal.Canto{
      dono_did: "did:plc:clara",
      tema: "papel",
      blocos: ~w(prosas recados quem-eu-leio),
      bio: "uma bio para conhecer a clara",
      links: [%Quintal.Canto.Link{titulo: "meu site", url: "https://example.com"}],
      updated_at: DateTime.utc_now()
    })

    {:ok, view, _html} = live(conn, "/passear")
    html = view |> element("button", "passear") |> render_click()

    assert html =~ "uma bio para conhecer a clara"
    assert html =~ "meu site"
    assert html =~ "clara.bsky.social"
    assert html =~ "visitar esse canto"
    assert html =~ "outro canto"
    refute html =~ "uma prosa para ser descoberta"
  end

  test "passear sem outros cantos mostra um estado vazio público", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/passear")
    html = view |> element("button", "passear") |> render_click()

    assert html =~ "o axô nadou o quintal inteiro e não achou ninguém por aqui ainda"
    assert html =~ "voltar pro quintal"
    refute html =~ "/prosear"
  end

  test "fim do passeio avisa e só repete quando a pessoa reinicia", %{conn: conn} do
    Repo.insert!(%Quintal.Identidade{
      did: "did:plc:clara",
      handle: "clara.bsky.social",
      pds_url: "https://pds.example",
      atualizado_em: DateTime.utc_now()
    })

    {:ok, view, _html} = live(conn, "/passear")
    primeira = view |> element("button", "passear") |> render_click()
    segunda = view |> element("button", "outro canto") |> render_click()

    assert primeira =~ "clara.bsky.social"
    assert segunda =~ "você já passeou por todos os cantos de hoje"
    assert segunda =~ "recomeçar o passeio"

    terceira = view |> element("button", "recomeçar o passeio") |> render_click()
    assert terceira =~ "clara.bsky.social"
  end

  test "ir direto leva ao canto pelo handle, com ou sem arroba", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/passear")

    assert {:error, {:live_redirect, %{to: "/canto/clara.bsky.social"}}} =
             view
             |> element("form.passear__direto")
             |> render_submit(%{handle: " @Clara.bsky.social "})
  end

  test "ir direto com campo vazio fica quieto na tela inicial", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/passear")

    html =
      view
      |> element("form.passear__direto")
      |> render_submit(%{handle: "  "})

    assert html =~ "o axô acha um canto pra você conhecer"
  end
end
