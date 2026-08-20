defmodule Quintal.IngestaoTest do
  use Quintal.DataCase, async: false

  alias ProtoRune.Jetstream.Event
  alias Quintal.Blogroll
  alias Quintal.Blogrolls
  alias Quintal.Canto
  alias Quintal.Cantos
  alias Quintal.Depoimento
  alias Quintal.FirehoseCursor
  alias Quintal.Follow
  alias Quintal.Ingestao
  alias Quintal.Prosa
  alias Quintal.Recado
  alias Quintal.Repo
  alias Quintal.VisitaEvento

  setup do
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

    {:ok, pid} = start_supervised({Ingestao, jetstream: false, name: nil})
    {:ok, ingestao: pid}
  end

  defp commit(did, collection, rkey, operation, record \\ nil, time_us \\ 1) do
    %Event{
      type: :commit,
      did: did,
      collection: collection,
      rkey: rkey,
      operation: operation,
      record: record,
      cid: if(record, do: "bafy1"),
      time_us: time_us
    }
  end

  test "create de prosa vira upsert no índice", %{ingestao: ingestao} do
    record = %{"text" => "prosa via jetstream", "createdAt" => "2026-08-02T10:00:00Z"}
    event = commit("did:plc:beto", "place.quintal.feed.prosa", "abc", :create, record)

    send(ingestao, {:jetstream, event})
    espera(fn -> Repo.get(Prosa, "at://did:plc:beto/place.quintal.feed.prosa/abc") end)

    prosa = Repo.get!(Prosa, "at://did:plc:beto/place.quintal.feed.prosa/abc")
    assert prosa.texto == "prosa via jetstream"
    assert prosa.cid == "bafy1"

    # o eco da nossa própria escrita é o mesmo evento: upsert, não append
    send(ingestao, {:jetstream, %{event | time_us: 2}})
    espera(fn -> Repo.aggregate(Prosa, :count) == 1 end)
  end

  test "delete de prosa some do índice", %{ingestao: ingestao} do
    uri = "at://did:plc:beto/place.quintal.feed.prosa/abc"

    {:ok, _} =
      Quintal.Prosas.indexar("did:plc:beto", %{
        uri: uri,
        cid: "bafy",
        value: %{text: "efêmera", created_at: "2026-08-01T10:00:00Z"}
      })

    send(ingestao, {:jetstream, commit("did:plc:beto", "place.quintal.feed.prosa", "abc", :delete)})

    espera(fn -> Repo.get(Prosa, uri) == nil end)
  end

  test "create e delete de follow mantêm a vizinhança", %{ingestao: ingestao} do
    uri = "at://did:plc:alice/place.quintal.graph.follow/f1"
    record = %{"subject" => "did:plc:beto", "createdAt" => "2026-08-02T10:00:00Z"}

    send(ingestao, {:jetstream, commit("did:plc:alice", "place.quintal.graph.follow", "f1", :create, record)})

    espera(fn -> Repo.get_by(Follow, uri: uri) end)
    assert Repo.get_by!(Follow, uri: uri).seguido_did == "did:plc:beto"

    send(
      ingestao,
      {:jetstream, commit("did:plc:alice", "place.quintal.graph.follow", "f1", :delete, nil, 2)}
    )

    espera(fn -> Repo.get_by(Follow, uri: uri) == nil end)
  end

  test "create e delete de recado mantêm o livro de visitas", %{ingestao: ingestao} do
    uri = "at://did:plc:beto/place.quintal.canto.recado/r1"
    record = %{"subject" => "did:plc:alice", "text" => "oi alice", "createdAt" => "2026-08-02T10:00:00Z"}

    send(ingestao, {:jetstream, commit("did:plc:beto", "place.quintal.canto.recado", "r1", :create, record)})

    espera(fn -> Repo.get(Recado, uri) end)
    assert Repo.get!(Recado, uri).subject_did == "did:plc:alice"
    assert Repo.get_by(VisitaEvento, dono_did: "did:plc:alice", tipo: "recado", ref_uri: uri)

    send(
      ingestao,
      {:jetstream, commit("did:plc:beto", "place.quintal.canto.recado", "r1", :delete, nil, 2)}
    )

    espera(fn -> Repo.get(Recado, uri) == nil end)
    assert Repo.get_by(VisitaEvento, ref_uri: uri) == nil
  end

  test "create e delete de depoimento mantêm o índice", %{ingestao: ingestao} do
    uri = "at://did:plc:beto/place.quintal.canto.depoimento/d1"
    record = %{"subject" => "did:plc:alice", "text" => "otima pessoa", "createdAt" => "2026-08-02T10:00:00Z"}

    send(
      ingestao,
      {:jetstream, commit("did:plc:beto", "place.quintal.canto.depoimento", "d1", :create, record)}
    )

    espera(fn -> Repo.get(Depoimento, uri) end)
    assert Repo.get!(Depoimento, uri).aceito == nil

    send(
      ingestao,
      {:jetstream, commit("did:plc:beto", "place.quintal.canto.depoimento", "d1", :delete, nil, 2)}
    )

    espera(fn -> Repo.get(Depoimento, uri) == nil end)
  end

  test "create e delete de blogroll mantêm o quem eu leio", %{ingestao: ingestao} do
    record = %{
      "items" => [%{"did" => "did:plc:alice", "note" => "vizinha"}],
      "updatedAt" => "2026-08-02T10:00:00Z"
    }

    send(ingestao, {:jetstream, commit("did:plc:beto", "place.quintal.canto.blogroll", "self", :create, record)})

    espera(fn -> Repo.get(Blogroll, "did:plc:beto") end)
    assert [item] = Blogrolls.get("did:plc:beto").items
    assert item.did == "did:plc:alice"

    send(
      ingestao,
      {:jetstream, commit("did:plc:beto", "place.quintal.canto.blogroll", "self", :delete, nil, 2)}
    )

    espera(fn -> Repo.get(Blogroll, "did:plc:beto") == nil end)
  end

  test "create de canto.config arruma o canto; delete é ignorado", %{ingestao: ingestao} do
    record = %{"tema" => "madrugada", "blocos" => ~w(bio prosas), "updatedAt" => "2026-08-02T10:00:00Z"}

    send(ingestao, {:jetstream, commit("did:plc:beto", "place.quintal.canto.config", "self", :create, record)})

    espera(fn -> Repo.get(Canto, "did:plc:beto") end)
    assert Cantos.get("did:plc:beto").tema == "madrugada"

    send(
      ingestao,
      {:jetstream, commit("did:plc:beto", "place.quintal.canto.config", "self", :delete, nil, 2)}
    )

    espera_cursor(ingestao, 2)
    assert Repo.get(Canto, "did:plc:beto")
  end

  test "commit fora do place.quintal.* é ignorado", %{ingestao: ingestao} do
    record = %{"text" => "post do bluesky", "createdAt" => "2026-08-02T10:00:00Z"}
    event = commit("did:plc:beto", "app.bsky.feed.post", "abc", :create, record)

    send(ingestao, {:jetstream, event})

    espera_cursor(ingestao, 1)
    assert Repo.aggregate(Prosa, :count) == 0
  end

  test "evento identity atualiza a identidade", %{ingestao: ingestao} do
    send(
      ingestao,
      {:jetstream,
       %Event{
         type: :identity,
         did: "did:plc:beto",
         time_us: 1,
         payload: %{"identity" => %{"did" => "did:plc:beto", "handle" => "beto.quintal.blog.br"}}
       }}
    )

    espera(fn -> Repo.get!(Quintal.Identidade, "did:plc:beto").handle == "beto.quintal.blog.br" end)
  end

  test "cursor é persistido para o boot retomar", %{ingestao: ingestao} do
    send(ingestao, {:jetstream, commit("did:plc:beto", "place.quintal.feed.prosa", "abc", :delete, nil, 42)})
    espera_cursor(ingestao, 42)

    send(ingestao, :persist_cursor)
    espera(fn -> Repo.get(FirehoseCursor, 1) end)

    assert Repo.get!(FirehoseCursor, 1).cursor == 42
  end

  defp espera_cursor(ingestao, cursor) do
    espera(fn -> :sys.get_state(ingestao).last_cursor == cursor end)
  end

  defp espera(fun, tentativas \\ 50)

  defp espera(_fun, 0), do: raise("condição não chegou a tempo")

  defp espera(fun, tentativas) do
    if fun.() do
      true
    else
      Process.sleep(20)
      espera(fun, tentativas - 1)
    end
  end
end
