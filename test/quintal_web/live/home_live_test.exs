defmodule QuintalWeb.HomeLiveTest do
  use QuintalWeb.ConnCase, async: true

  import Mox
  import Phoenix.LiveViewTest

  alias Quintal.Auth.Mock
  alias Quintal.PDS.Mock, as: PDSMock

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

  test "deslogada: sugere entrar com handle atproto", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")

    assert html =~ "uma vizinhança de blogs"
    assert html =~ ~s(action="/oauth/login")
    assert html =~ ~s(name="handle")
  end

  test "logada: composer e o vazio do spec, sem prosa ainda", %{conn: conn} do
    {:ok, _view, html} = live(loga_como_alice(conn), "/")

    assert html =~ "oi, alice.bsky.social"
    assert html =~ "prosear"
    assert html =~ "por aqui ainda tá quieto"
    assert html =~ "/oauth/logout"
  end

  test "prosear: escreve no pds e a prosa aparece na hora", %{conn: conn} do
    Quintal.Repo.insert!(%Quintal.Identidade{
      did: "did:plc:alice",
      handle: "alice.bsky.social",
      pds_url: "https://pds.example",
      atualizado_em: DateTime.utc_now()
    })

    stub(PDSMock, :create_record, fn _session, "place.quintal.feed.prosa", _record ->
      {:ok, %{uri: "at://did:plc:alice/place.quintal.feed.prosa/abc", cid: "bafy1"}}
    end)

    {:ok, view, _html} = live(loga_como_alice(conn), "/")

    html =
      view
      |> form("form[phx-submit=prosear]", %{texto: "bom dia, quintal"})
      |> render_submit()

    assert html =~ "pronto, sua prosa tá no quintal"
    assert html =~ "bom dia, quintal"
  end

  test "prosear com texto vazio mostra o erro genérico do spec", %{conn: conn} do
    {:ok, view, _html} = live(loga_como_alice(conn), "/")

    # o textarea é required, mas a borda também valida: texto em branco
    # nunca sai de casa.
    html = render_submit(view, "prosear", %{texto: "   "})

    assert html =~ "ih, algo deu errado. tenta de novo?"
  end

  test "composer oferece os quatro tipos, quietos no chrome", %{conn: conn} do
    {:ok, _view, html} = live(loga_como_alice(conn), "/")

    assert html =~ ~s(<select name="tipo")
    for tipo <- ["nota", "pergunta", "crônica", "ensaio"], do: assert(html =~ tipo)
  end

  test "apagar: some da lista, do pds e do índice", %{conn: conn} do
    Quintal.Repo.insert!(%Quintal.Identidade{
      did: "did:plc:alice",
      handle: "alice.bsky.social",
      pds_url: "https://pds.example",
      atualizado_em: DateTime.utc_now()
    })

    uri = "at://did:plc:alice/place.quintal.feed.prosa/abc"

    {:ok, _} =
      Quintal.Prosas.indexar("did:plc:alice", %{
        uri: uri,
        cid: "bafy",
        value: %{text: "prosa efêmera", created_at: "2026-08-01T10:00:00Z"}
      })

    stub(PDSMock, :delete_record, fn _session, "place.quintal.feed.prosa", "abc", _opts -> :ok end)

    {:ok, view, html} = live(loga_como_alice(conn), "/")
    assert html =~ "prosa efêmera"
    assert html =~ "apagar essa prosa? ela sai do seu pds também."

    html = render_click(view, "apagar", %{"uri" => uri})

    refute html =~ "prosa efêmera"
    assert Quintal.Repo.get(Quintal.Prosa, uri) == nil
  end

  test "seguir um canto: entra na vizinhança e as prosas dele viram feed", %{conn: conn} do
    for {did, handle} <- [
          {"did:plc:alice", "alice.bsky.social"},
          {"did:plc:beto", "beto.bsky.social"}
        ] do
      Quintal.Repo.insert!(%Quintal.Identidade{
        did: did,
        handle: handle,
        pds_url: "https://pds.example",
        atualizado_em: DateTime.utc_now()
      })
    end

    {:ok, _} =
      Quintal.Prosas.indexar("did:plc:beto", %{
        uri: "at://did:plc:beto/place.quintal.feed.prosa/abc",
        cid: "bafy",
        value: %{text: "bom dia do beto", created_at: "2026-08-02T10:00:00Z"}
      })

    stub(PDSMock, :create_record, fn _session, "place.quintal.graph.follow", _record ->
      {:ok, %{uri: "at://did:plc:alice/place.quintal.graph.follow/f1", cid: "bafy"}}
    end)

    stub(PDSMock, :delete_record, fn _session, "place.quintal.graph.follow", "f1", _opts -> :ok end)

    {:ok, view, html} = live(loga_como_alice(conn), "/")

    # feed vazio até seguir alguém
    assert html =~ "que tal seguir um canto?"
    refute html =~ "bom dia do beto"

    html =
      view
      |> form("form[phx-submit=seguir]", %{quem: "beto.bsky.social"})
      |> render_submit()

    assert html =~ "agora esse canto tá na sua vizinhança"
    assert html =~ "beto.bsky.social"
    assert html =~ "bom dia do beto"

    html = render_click(view, "deixar_de_seguir", %{"uri" => "at://did:plc:alice/place.quintal.graph.follow/f1"})
    refute html =~ "bom dia do beto"
  end

  test "seguir canto desconhecido mostra o axô procurando", %{conn: conn} do
    {:ok, view, _html} = live(loga_como_alice(conn), "/")

    html =
      view
      |> form("form[phx-submit=seguir]", %{quem: "ninguem.bsky.social"})
      |> render_submit()

    assert html =~ "o axô procurou, procurou... e não achou esse canto"
  end

  test "sessão inválida cai no estado deslogado", %{conn: conn} do
    stub(Mock, :current_session, fn "did:plc:ninguem" -> {:error, :not_found} end)

    conn = init_test_session(conn, %{quintal_did: "did:plc:ninguem"})

    {:ok, _view, html} = live(conn, "/")

    assert html =~ "uma vizinhança de blogs"
  end
end
