defmodule QuintalWeb.VisitasLiveTest do
  use QuintalWeb.ConnCase, async: true

  import Mox
  import Phoenix.LiveViewTest

  alias Quintal.Auth.Mock
  alias Quintal.Repo

  setup :verify_on_exit!

  setup %{conn: conn} do
    for {did, handle} <- [
          {"did:plc:alice", "alice.bsky.social"},
          {"did:plc:beto", "beto.bsky.social"}
        ] do
      Repo.insert!(%Quintal.Identidade{
        did: did,
        handle: handle,
        pds_url: "https://pds.example",
        atualizado_em: DateTime.utc_now()
      })
    end

    session = %ProtoRune.Atproto.OAuth.Session{
      did: "did:plc:alice",
      handle: "alice.bsky.social",
      access_token: "token-abc",
      dpop_key: "key",
      dpop_jwk: %{},
      service_url: "https://pds.example"
    }

    stub(Mock, :current_session, fn "did:plc:alice" -> {:ok, session} end)

    {:ok, conn: init_test_session(conn, %{quintal_did: "did:plc:alice"})}
  end

  test "resolver os últimos depoimentos revela o vazio e uma ação sugerida", %{conn: conn} do
    for rkey <- ["aceitar", "silenciar"] do
      Repo.insert!(%Quintal.Depoimento{
        uri: "at://did:plc:beto/place.quintal.canto.depoimento/#{rkey}",
        autor_did: "did:plc:beto",
        subject_did: "did:plc:alice",
        texto: "gosto do seu canto",
        created_at: DateTime.utc_now()
      })
    end

    {:ok, view, _html} = live(conn, "/visitas")

    html =
      view
      |> element(~s(button[phx-value-uri="at://did:plc:beto/place.quintal.canto.depoimento/aceitar"]), "aceitar")
      |> render_click()

    refute html =~ "ninguém passou por aqui desde sua última visita"

    html =
      view
      |> element(~s(button[phx-value-uri="at://did:plc:beto/place.quintal.canto.depoimento/silenciar"]), "deixar quieto")
      |> render_click()

    assert html =~ "ninguém passou por aqui desde sua última visita"
    assert html =~ "passear com o axô"
  end
end
