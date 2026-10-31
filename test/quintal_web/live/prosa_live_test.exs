defmodule QuintalWeb.ProsaLiveTest do
  use QuintalWeb.ConnCase, async: true

  import Mox
  import Phoenix.LiveViewTest

  alias Quintal.Auth.Mock

  setup :verify_on_exit!

  defp sessao_alice do
    %ProtoRune.Atproto.OAuth.Session{
      did: "did:plc:alice",
      handle: "alice.bsky.social",
      access_token: "token-abc",
      dpop_key: "key",
      dpop_jwk: %{},
      service_url: "https://pds.example"
    }
  end

  defp loga_como_alice(conn) do
    stub(Mock, :current_session, fn "did:plc:alice" -> {:ok, sessao_alice()} end)
    init_test_session(conn, %{quintal_did: "did:plc:alice"})
  end

  test "a resposta inline renderiza uma única régua markdown", %{conn: conn} do
    Quintal.Repo.insert!(%Quintal.Identidade{
      did: "did:plc:beto",
      handle: "beto.bsky.social",
      pds_url: "https://pds.example",
      atualizado_em: DateTime.utc_now()
    })

    {:ok, _prosa} =
      Quintal.Prosas.indexar("did:plc:beto", %{
        uri: "at://did:plc:beto/place.quintal.feed.prosa/b1",
        cid: "bafy",
        value: %{text: "bom dia do beto", created_at: "2026-08-02T10:00:00Z"}
      })

    {:ok, _view, html} = live(loga_como_alice(conn), "/canto/beto.bsky.social/prosa/b1")

    assert length(Regex.scan(~r/class="md-ferramentas"/, html)) == 1
  end
end
