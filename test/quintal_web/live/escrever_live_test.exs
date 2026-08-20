defmodule QuintalWeb.EscreverLiveTest do
  use QuintalWeb.ConnCase, async: false

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

  defp identidade(did, handle) do
    Quintal.Repo.insert!(%Quintal.Identidade{
      did: did,
      handle: handle,
      pds_url: "https://pds.example",
      atualizado_em: DateTime.utc_now()
    })
  end

  defp prosa_do_beto do
    identidade("did:plc:beto", "beto.bsky.social")

    {:ok, prosa} =
      Quintal.Prosas.indexar("did:plc:beto", %{
        uri: "at://did:plc:beto/place.quintal.feed.prosa/abc",
        cid: "bafy",
        value: %{text: "bom dia do beto", created_at: "2026-08-02T10:00:00Z"}
      })

    prosa
  end

  test "prosa nova: chips, régua e voltar pro início, sem chrome", %{conn: conn} do
    {:ok, _view, html} = live(loga_como_alice(conn), "/prosear")

    assert html =~ "voltar"
    assert html =~ "prosear"
    assert html =~ ~s(type="radio" name="tipo")
    for tipo <- ["nota", "pergunta", "crônica", "ensaio"], do: assert(html =~ tipo)
    assert html =~ "formatação do texto"
    refute html =~ "nav-movel"
    refute html =~ "chrome__topo"
  end

  test "?tipo=ensaio abre com o radio marcado e o título no fluxo", %{conn: conn} do
    {:ok, _view, html} = live(loga_como_alice(conn), "/prosear?tipo=ensaio")

    assert html =~ ~s(value="ensaio" checked)
    assert html =~ "título, se quiser"
    assert html =~ "escreve sem pressa"
  end

  test "?tipo= inválido cai na nota", %{conn: conn} do
    {:ok, _view, html} = live(loga_como_alice(conn), "/prosear?tipo=xyz")

    assert html =~ ~s(value="nota" checked)
  end

  test "escrever prosa publica e volta pro início", %{conn: conn} do
    identidade("did:plc:alice", "alice.bsky.social")

    stub(Quintal.PDS.Mock, :create_record, fn _session, "place.quintal.feed.prosa", _record ->
      {:ok, %{uri: "at://did:plc:alice/place.quintal.feed.prosa/abc", cid: "bafy1"}}
    end)

    {:ok, view, _html} = live(loga_como_alice(conn), "/prosear")

    {:error, {:live_redirect, %{to: "/inicio"}}} =
      view
      |> form("#escrever", %{texto: "bom dia, quintal", tipo: "nota"})
      |> render_submit()
  end

  test "resposta: card da mãe no topo, sem chips, voltar pra thread", %{conn: conn} do
    prosa = prosa_do_beto()

    {:ok, _view, html} = live(loga_como_alice(conn), "/prosear?reply=#{prosa.uri}")

    assert html =~ "beto.bsky.social"
    assert html =~ "bom dia do beto"
    assert html =~ "responder com uma prosa..."
    assert html =~ "responder"
    refute html =~ ~s(type="radio" name="tipo")
  end

  test "resposta com mãe fora do índice cai na prosa nova", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/prosear"}}} =
             live(loga_como_alice(conn), "/prosear?reply=at://did:plc:ghost/place.quintal.feed.prosa/xyz")
  end

  test "escrever resposta publica com reply e volta pra thread", %{conn: conn} do
    prosa = prosa_do_beto()
    identidade("did:plc:alice", "alice.bsky.social")

    stub(Quintal.PDS.Mock, :create_record, fn _session,
                                              "place.quintal.feed.prosa",
                                              %{"reply" => %{"parent" => %{"uri" => uri}}} ->
      assert uri == prosa.uri
      {:ok, %{uri: "at://did:plc:alice/place.quintal.feed.prosa/res", cid: "bafy2"}}
    end)

    {:ok, view, _html} = live(loga_como_alice(conn), "/prosear?reply=#{prosa.uri}")

    {:error, {:live_redirect, %{to: "/canto/beto.bsky.social/prosa/abc"}}} =
      view
      |> form("#escrever", %{texto: "bom dia, beto"})
      |> render_submit()
  end

  test "recado: card do canto, sem chips nem régua, limite curto", %{conn: conn} do
    prosa_do_beto()

    {:ok, _view, html} = live(loga_como_alice(conn), "/recadar?para=beto.bsky.social")

    assert html =~ "beto.bsky.social"
    assert html =~ "livro de visitas aberto"
    assert html =~ "deixa um recado pra beto.bsky.social"
    assert html =~ "recadar"
    assert html =~ ~s(maxlength="500")
    refute html =~ ~s(type="radio" name="tipo")
    refute html =~ "formatação do texto"
  end

  test "recado no próprio canto volta pro canto", %{conn: conn} do
    identidade("did:plc:alice", "alice.bsky.social")

    assert {:error, {:live_redirect, %{to: "/canto/alice.bsky.social"}}} =
             live(loga_como_alice(conn), "/recadar?para=alice.bsky.social")
  end

  test "recado pra handle desconhecido volta pro início", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/inicio"}}} =
             live(loga_como_alice(conn), "/recadar?para=ghost.bsky.social")
  end

  test "escrever recado publica e volta pro canto", %{conn: conn} do
    prosa_do_beto()
    identidade("did:plc:alice", "alice.bsky.social")

    stub(Quintal.PDS.Mock, :create_record, fn _session, "place.quintal.canto.recado", %{"subject" => "did:plc:beto"} ->
      {:ok, %{uri: "at://did:plc:alice/place.quintal.canto.recado/r1", cid: "bafy3"}}
    end)

    {:ok, view, _html} = live(loga_como_alice(conn), "/recadar?para=beto.bsky.social")

    {:error, {:live_redirect, %{to: "/canto/beto.bsky.social"}}} =
      view
      |> form("#escrever", %{texto: "belo canto, beto"})
      |> render_submit()
  end
end
