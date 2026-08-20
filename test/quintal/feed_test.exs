defmodule Quintal.FeedTest do
  use Quintal.DataCase, async: true

  alias Quintal.Feed
  alias Quintal.Follows
  alias Quintal.Prosas
  alias Quintal.Repo

  setup do
    for {did, handle} <- [
          {"did:plc:alice", "alice.bsky.social"},
          {"did:plc:beto", "beto.bsky.social"},
          {"did:plc:clara", "clara.bsky.social"}
        ] do
      Repo.insert!(%Quintal.Identidade{
        did: did,
        handle: handle,
        pds_url: "https://pds.example",
        atualizado_em: DateTime.utc_now()
      })
    end

    :ok
  end

  defp segue(seguidor, seguido, n \\ 1) do
    {:ok, _} =
      Follows.indexar(seguidor, %{
        uri: "at://#{seguidor}/place.quintal.graph.follow/f#{n}",
        value: %{subject: seguido, created_at: "2026-08-01T10:00:00Z"}
      })
  end

  defp prosa(autor, texto, created_at) do
    {:ok, _} =
      Prosas.indexar(autor, %{
        uri: "at://#{autor}/place.quintal.feed.prosa/#{texto}",
        cid: "bafy",
        value: %{text: texto, created_at: created_at}
      })
  end

  test "prosas da vizinhança e as próprias, lado a lado" do
    segue("did:plc:alice", "did:plc:beto")
    prosa("did:plc:beto", "prosa do beto", "2026-08-02T10:00:00Z")
    prosa("did:plc:clara", "prosa da clara", "2026-08-02T11:00:00Z")
    prosa("did:plc:alice", "prosa da alice", "2026-08-02T12:00:00Z")

    feed = Feed.list("did:plc:alice")

    # clara não é lida por alice, fica de fora; a própria prosa entra
    assert Enum.map(feed, & &1.texto) == ["prosa da alice", "prosa do beto"]
    assert hd(feed).autor.handle == "alice.bsky.social"
  end

  test "cronológico, da mais nova para a mais antiga, sem ranqueamento" do
    segue("did:plc:alice", "did:plc:beto")
    segue("did:plc:alice", "did:plc:clara", 2)

    prosa("did:plc:beto", "antiga", "2026-08-01T10:00:00Z")
    prosa("did:plc:clara", "nova", "2026-08-03T10:00:00Z")
    prosa("did:plc:beto", "meio", "2026-08-02T10:00:00Z")

    assert ["nova", "meio", "antiga"] ==
             "did:plc:alice" |> Feed.list() |> Enum.map(& &1.texto)
  end

  test "paginação por cursor retoma de onde parou" do
    segue("did:plc:alice", "did:plc:beto")

    for dia <- 1..5 do
      prosa("did:plc:beto", "dia#{dia}", "2026-08-0#{dia}T10:00:00Z")
    end

    pagina1 = Feed.list("did:plc:alice", limit: 2)
    assert Enum.map(pagina1, & &1.texto) == ["dia5", "dia4"]

    cursor = pagina1 |> List.last() |> Feed.cursor()
    pagina2 = Feed.list("did:plc:alice", limit: 2, cursor: cursor)
    assert Enum.map(pagina2, & &1.texto) == ["dia3", "dia2"]

    cursor = pagina2 |> List.last() |> Feed.cursor()
    pagina3 = Feed.list("did:plc:alice", limit: 2, cursor: cursor)
    assert Enum.map(pagina3, & &1.texto) == ["dia1"]
  end

  test "prosa nova entre páginas não duplica nem pula" do
    segue("did:plc:alice", "did:plc:beto")
    prosa("did:plc:beto", "velha", "2026-08-01T10:00:00Z")

    pagina1 = Feed.list("did:plc:alice", limit: 1)
    cursor = pagina1 |> List.last() |> Feed.cursor()

    prosa("did:plc:beto", "novíssima", "2026-08-05T10:00:00Z")

    assert Feed.list("did:plc:alice", cursor: cursor) == []
  end

  test "cursor inválido volta para a primeira página" do
    segue("did:plc:alice", "did:plc:beto")
    prosa("did:plc:beto", "única", "2026-08-01T10:00:00Z")

    assert [%{texto: "única"}] = Feed.list("did:plc:alice", cursor: "lixo")
  end
end
