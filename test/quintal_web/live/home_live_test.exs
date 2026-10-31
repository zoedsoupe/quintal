defmodule QuintalWeb.HomeLiveTest do
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

  test "deslogada: login em primeiro plano e uma navegação secundária", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")

    assert html =~ "seu canto na vizinhança"
    assert html =~ "já mora no quintal?"
    assert html =~ ~s(action="/oauth/login")
    assert html =~ ~s(name="handle")
    assert html =~ "entrar com atproto"
    assert html =~ "tenho um convite"
    assert html =~ "passear com o axô"
    assert html =~ ~s(class="boas-vindas__links")
    assert html =~ "regrinhas de convivência"
    refute html =~ "class=\"rodape\""
    assert length(Regex.scan(~r/class="boas-vindas__links"/, html)) == 1
    assert length(Regex.scan(~r/class="botao botao--primario"/, html)) == 1
    refute html =~ "botao--fantasma"
  end

  test "convite guardado vira a ação principal e orienta o login", %{conn: conn} do
    conn = init_test_session(conn, %{convite: "axo-12345678"})
    {:ok, _view, html} = live(conn, "/")

    assert html =~ "seu convite tá guardado"
    assert html =~ "seu handle atproto"
    assert html =~ ~s(autofocus)
    assert html =~ ~s(class="botao botao--primario" type="submit")
    assert html =~ "criar conta atproto"
    refute html =~ "tenho um convite"
  end

  test "logada: a landing vira redirect pro início", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/inicio"}}} = live(loga_como_alice(conn), "/")
  end

  test "logada: composer no topo e o vazio do spec, sem prosa ainda", %{conn: conn} do
    {:ok, _view, html} = live(loga_como_alice(conn), "/inicio")

    assert html =~ "como foi seu dia?"
    assert html =~ "prosear"
    assert html =~ "por aqui ainda tá quieto. que tal escrever a primeira prosa?"
    assert html =~ "/oauth/logout"
  end

  test "prosear: escreve no pds e a prosa aparece na hora", %{conn: conn} do
    Quintal.Repo.insert!(%Quintal.Identidade{
      did: "did:plc:alice",
      handle: "alice.bsky.social",
      pds_url: "https://pds.example",
      atualizado_em: DateTime.utc_now()
    })

    stub(Quintal.PDS.Mock, :create_record, fn _session, "place.quintal.feed.prosa", _record ->
      {:ok, %{uri: "at://did:plc:alice/place.quintal.feed.prosa/abc", cid: "bafy1"}}
    end)

    {:ok, view, _html} = live(loga_como_alice(conn), "/inicio")

    html =
      view
      |> form("form[phx-submit=prosear]", %{texto: "bom dia, quintal"})
      |> render_submit()

    assert html =~ "pronto, sua prosa tá no quintal"
    assert html =~ "bom dia, quintal"
  end

  test "prosear com texto vazio mostra o erro genérico do spec", %{conn: conn} do
    {:ok, view, _html} = live(loga_como_alice(conn), "/inicio")

    # o textarea é required, mas a borda também valida: texto em branco
    # nunca sai de casa.
    html = render_submit(view, "prosear", %{texto: "   "})

    assert html =~ "ih, algo deu errado. tenta de novo?"
  end

  test "composer oferece os quatro tipos como pills quietas", %{conn: conn} do
    {:ok, _view, html} = live(loga_como_alice(conn), "/inicio")

    assert html =~ ~s(type="radio" name="tipo")
    for tipo <- ["nota", "pergunta", "crônica", "ensaio"], do: assert(html =~ tipo)
  end

  test "feed com fim declarado: a despedida aparece quando acaba", %{conn: conn} do
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

    {:ok, _} =
      Quintal.Follows.indexar("did:plc:alice", %{
        uri: "at://did:plc:alice/place.quintal.graph.follow/f1",
        value: %{subject: "did:plc:beto", created_at: "2026-08-02T10:00:00Z"}
      })

    {:ok, _view, html} = live(loga_como_alice(conn), "/inicio")

    assert html =~ "bom dia do beto"
    assert html =~ "você viu tudo do seu quintal por hoje. vai tomar um café."
  end

  test "sessão inválida cai no estado deslogado", %{conn: conn} do
    stub(Mock, :current_session, fn "did:plc:ninguem" -> {:error, :not_found} end)

    conn = init_test_session(conn, %{quintal_did: "did:plc:ninguem"})

    {:ok, _view, html} = live(conn, "/")

    assert html =~ "seu canto na vizinhança"
  end
end
