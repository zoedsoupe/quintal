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
end
