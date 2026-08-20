defmodule Quintal.PassearTest do
  use Quintal.DataCase, async: true

  alias Quintal.Passear
  alias Quintal.Prosas
  alias Quintal.Repo

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

    :ok
  end

  defp prosa(autor, n) do
    {:ok, _} =
      Prosas.indexar(autor, %{
        uri: "at://#{autor}/place.quintal.feed.prosa/p#{n}",
        cid: "bafy",
        value: %{text: "prosa #{n} de #{autor}", created_at: "2026-08-01T10:00:00Z"}
      })
  end

  defp resposta(autor, n, parent_uri) do
    {:ok, _} =
      Prosas.indexar(autor, %{
        uri: "at://#{autor}/place.quintal.feed.prosa/r#{n}",
        cid: "bafy",
        value: %{
          text: "resposta #{n} de #{autor}",
          created_at: "2026-08-01T10:00:00Z",
          reply: %{
            root: %{uri: parent_uri, cid: "bafy"},
            parent: %{uri: parent_uri, cid: "bafy"}
          }
        }
      })
  end

  test "índice vazio não tem passeio" do
    assert Passear.prosa_aleatoria("did:plc:alice") == nil
    assert Passear.prosa_aleatoria(nil) == nil
  end

  test "sorteia prosa de outro canto, nunca a própria" do
    prosa("did:plc:beto", 1)
    prosa("did:plc:alice", 2)

    for _ <- 1..20 do
      assert %Quintal.Prosa{autor_did: "did:plc:beto", autor: %{handle: "beto.bsky.social"}} =
               Passear.prosa_aleatoria("did:plc:alice")
    end
  end

  test "deslogada passeia pelo índice inteiro" do
    prosa("did:plc:alice", 1)

    assert %Quintal.Prosa{autor_did: "did:plc:alice"} = Passear.prosa_aleatoria(nil)
  end

  test "só há a própria prosa no índice: não passeia" do
    prosa("did:plc:alice", 1)

    assert Passear.prosa_aleatoria("did:plc:alice") == nil
  end

  test "respostas ficam fora do passeio: fora de contexto são uma carta ruim" do
    prosa("did:plc:beto", 1)
    resposta("did:plc:beto", 1, "at://did:plc:beto/place.quintal.feed.prosa/p1")

    for _ <- 1..20 do
      assert %Quintal.Prosa{uri: "at://did:plc:beto/place.quintal.feed.prosa/p1"} =
               Passear.prosa_aleatoria("did:plc:alice")
    end
  end

  test "cartas já vistas ficam fora do sorteio até esgotar" do
    prosa("did:plc:beto", 1)
    prosa("did:plc:beto", 2)

    uri1 = "at://did:plc:beto/place.quintal.feed.prosa/p1"
    uri2 = "at://did:plc:beto/place.quintal.feed.prosa/p2"

    assert %Quintal.Prosa{uri: ^uri2} = Passear.prosa_aleatoria("did:plc:alice", [uri1])
    assert Passear.prosa_aleatoria("did:plc:alice", [uri1, uri2]) == nil
  end
end
