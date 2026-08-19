defmodule Quintal.IngestaoTest do
  use Quintal.DataCase, async: false

  alias ProtoRune.Firehose.Event
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

    {:ok, pid} = start_supervised({Ingestao, firehose: false, name: nil})
    {:ok, ingestao: pid}
  end

  defp commit(repo, ops, blocks \\ %{}, seq \\ 1) do
    %Event{type: :commit, repo: repo, seq: seq, ops: ops, blocks: blocks}
  end

  defp op_create(path, cid), do: %{action: :create, path: path, cid: cid}

  test "create de prosa vira upsert no índice", %{ingestao: ingestao} do
    event =
      commit(
        "did:plc:beto",
        [op_create("place.quintal.feed.prosa/abc", "bafy1")],
        %{"bafy1" => %{"text" => "prosa via firehose", "createdAt" => "2026-08-02T10:00:00Z"}}
      )

    send(ingestao, {:firehose, event})
    espera(fn -> Repo.get(Prosa, "at://did:plc:beto/place.quintal.feed.prosa/abc") end)

    prosa = Repo.get!(Prosa, "at://did:plc:beto/place.quintal.feed.prosa/abc")
    assert prosa.texto == "prosa via firehose"
    assert prosa.cid == "bafy1"

    # o eco da nossa própria escrita é o mesmo evento: upsert, não append
    send(ingestao, {:firehose, %{event | seq: 2}})
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

    send(
      ingestao,
      {:firehose, commit("did:plc:beto", [%{action: :delete, path: "place.quintal.feed.prosa/abc", cid: nil}])}
    )

    espera(fn -> Repo.get(Prosa, uri) == nil end)
  end

  test "create e delete de follow mantêm a vizinhança", %{ingestao: ingestao} do
    uri = "at://did:plc:alice/place.quintal.graph.follow/f1"

    send(
      ingestao,
      {:firehose,
       commit(
         "did:plc:alice",
         [op_create("place.quintal.graph.follow/f1", "bafy2")],
         %{"bafy2" => %{"subject" => "did:plc:beto", "createdAt" => "2026-08-02T10:00:00Z"}}
       )}
    )

    espera(fn -> Repo.get_by(Follow, uri: uri) end)
    assert Repo.get_by!(Follow, uri: uri).seguido_did == "did:plc:beto"

    send(
      ingestao,
      {:firehose, commit("did:plc:alice", [%{action: :delete, path: "place.quintal.graph.follow/f1", cid: nil}], %{}, 2)}
    )

    espera(fn -> Repo.get_by(Follow, uri: uri) == nil end)
  end

  test "create e delete de recado mantêm o livro de visitas", %{ingestao: ingestao} do
    uri = "at://did:plc:beto/place.quintal.canto.recado/r1"

    send(
      ingestao,
      {:firehose,
       commit(
         "did:plc:beto",
         [op_create("place.quintal.canto.recado/r1", "bafy4")],
         %{"bafy4" => %{"subject" => "did:plc:alice", "text" => "oi alice", "createdAt" => "2026-08-02T10:00:00Z"}}
       )}
    )

    espera(fn -> Repo.get(Recado, uri) end)
    assert Repo.get!(Recado, uri).subject_did == "did:plc:alice"
    assert Repo.get_by(VisitaEvento, dono_did: "did:plc:alice", tipo: "recado", ref_uri: uri)

    send(
      ingestao,
      {:firehose, commit("did:plc:beto", [%{action: :delete, path: "place.quintal.canto.recado/r1", cid: nil}], %{}, 2)}
    )

    espera(fn -> Repo.get(Recado, uri) == nil end)
    assert Repo.get_by(VisitaEvento, ref_uri: uri) == nil
  end

  test "create e delete de depoimento mantêm o índice", %{ingestao: ingestao} do
    uri = "at://did:plc:beto/place.quintal.canto.depoimento/d1"

    send(
      ingestao,
      {:firehose,
       commit(
         "did:plc:beto",
         [op_create("place.quintal.canto.depoimento/d1", "bafy5")],
         %{"bafy5" => %{"subject" => "did:plc:alice", "text" => "otima pessoa", "createdAt" => "2026-08-02T10:00:00Z"}}
       )}
    )

    espera(fn -> Repo.get(Depoimento, uri) end)
    assert Repo.get!(Depoimento, uri).aceito == nil

    send(
      ingestao,
      {:firehose,
       commit("did:plc:beto", [%{action: :delete, path: "place.quintal.canto.depoimento/d1", cid: nil}], %{}, 2)}
    )

    espera(fn -> Repo.get(Depoimento, uri) == nil end)
  end

  test "create e delete de blogroll mantêm o quem eu leio", %{ingestao: ingestao} do
    send(
      ingestao,
      {:firehose,
       commit(
         "did:plc:beto",
         [op_create("place.quintal.canto.blogroll/self", "bafy6")],
         %{
           "bafy6" => %{
             "items" => [%{"did" => "did:plc:alice", "note" => "vizinha"}],
             "updatedAt" => "2026-08-02T10:00:00Z"
           }
         }
       )}
    )

    espera(fn -> Repo.get(Blogroll, "did:plc:beto") end)
    assert [item] = Blogrolls.get("did:plc:beto").items
    assert item.did == "did:plc:alice"

    send(
      ingestao,
      {:firehose,
       commit("did:plc:beto", [%{action: :delete, path: "place.quintal.canto.blogroll/self", cid: nil}], %{}, 2)}
    )

    espera(fn -> Repo.get(Blogroll, "did:plc:beto") == nil end)
  end

  test "create de canto.config arruma o canto; delete é ignorado", %{ingestao: ingestao} do
    send(
      ingestao,
      {:firehose,
       commit(
         "did:plc:beto",
         [op_create("place.quintal.canto.config/self", "bafy7")],
         %{"bafy7" => %{"tema" => "madrugada", "blocos" => ~w(bio prosas), "updatedAt" => "2026-08-02T10:00:00Z"}}
       )}
    )

    espera(fn -> Repo.get(Canto, "did:plc:beto") end)
    assert Cantos.get("did:plc:beto").tema == "madrugada"

    send(
      ingestao,
      {:firehose, commit("did:plc:beto", [%{action: :delete, path: "place.quintal.canto.config/self", cid: nil}], %{}, 2)}
    )

    espera_seq(ingestao, 2)
    assert Repo.get(Canto, "did:plc:beto")
  end

  test "commit fora do place.quintal.* é ignorado", %{ingestao: ingestao} do
    event =
      commit(
        "did:plc:beto",
        [op_create("app.bsky.feed.post/abc", "bafy3")],
        %{"bafy3" => %{"text" => "post do bluesky", "createdAt" => "2026-08-02T10:00:00Z"}}
      )

    send(ingestao, {:firehose, event})

    espera_seq(ingestao, 1)
    assert Repo.aggregate(Prosa, :count) == 0
  end

  test "evento handle atualiza a identidade", %{ingestao: ingestao} do
    send(
      ingestao,
      {:firehose,
       %Event{
         type: :handle,
         repo: "did:plc:beto",
         seq: 1,
         payload: %{"did" => "did:plc:beto", "handle" => "beto.quintal.blog.br"}
       }}
    )

    espera(fn -> Repo.get!(Quintal.Identidade, "did:plc:beto").handle == "beto.quintal.blog.br" end)
  end

  test "cursor é persistido para o boot retomar", %{ingestao: ingestao} do
    send(ingestao, {:firehose, commit("did:plc:beto", [], %{}, 42)})
    espera_seq(ingestao, 42)

    send(ingestao, :persist_cursor)
    espera(fn -> Repo.get(FirehoseCursor, 1) end)

    assert Repo.get!(FirehoseCursor, 1).cursor == 42
  end

  defp espera_seq(ingestao, seq) do
    espera(fn -> :sys.get_state(ingestao).last_seq == seq end)
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
