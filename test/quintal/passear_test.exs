defmodule Quintal.PassearTest do
  use Quintal.DataCase, async: true

  alias Quintal.Passear
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

  test "índice vazio não tem passeio" do
    assert Passear.canto_aleatorio("did:plc:alice", ["did:plc:beto"]) == nil
  end

  test "sorteia cantos de outras pessoas, mesmo sem prosas" do
    for _ <- 1..20 do
      assert %Quintal.Identidade{did: "did:plc:beto", handle: "beto.bsky.social"} =
               Passear.canto_aleatorio("did:plc:alice")
    end
  end

  test "deslogada passeia pelo índice inteiro" do
    assert %Quintal.Identidade{did: did} = Passear.canto_aleatorio(nil)
    assert did in ["did:plc:alice", "did:plc:beto"]
  end

  test "cantos vistos ficam fora do sorteio até reiniciar" do
    assert %Quintal.Identidade{did: "did:plc:beto"} =
             Passear.canto_aleatorio("did:plc:alice", ["did:plc:alice"])

    assert Passear.canto_aleatorio("did:plc:alice", ["did:plc:alice", "did:plc:beto"]) == nil
    assert %Quintal.Identidade{did: "did:plc:beto"} = Passear.canto_aleatorio("did:plc:alice", [])
  end
end
