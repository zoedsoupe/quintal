defmodule Quintal.Auth.TokenStoreTest do
  use Quintal.DataCase, async: true

  alias ProtoRune.Security.Crypto
  alias Quintal.Auth.TokenStore

  @did "did:plc:alice"

  test "put/fetch/delete roundtrip" do
    assert {:error, :not_found} = TokenStore.fetch(@did, [])

    assert :ok = TokenStore.put(@did, "blob-cifrado", [])
    assert {:ok, "blob-cifrado"} = TokenStore.fetch(@did, [])

    assert :ok = TokenStore.delete(@did, [])
    assert {:error, :not_found} = TokenStore.fetch(@did, [])

    # deleting a missing entry is fine
    assert :ok = TokenStore.delete(@did, [])
  end

  test "put overwrites the blob for the same did" do
    assert :ok = TokenStore.put(@did, "velho", [])
    assert :ok = TokenStore.put(@did, "novo", [])
    assert {:ok, "novo"} = TokenStore.fetch(@did, [])
  end

  test "all/0 lists stored dids" do
    assert :ok = TokenStore.put("did:plc:alice", "a", [])
    assert :ok = TokenStore.put("did:web:bob.example", "b", [])

    assert Enum.sort(TokenStore.all()) == ["did:plc:alice", "did:web:bob.example"]
  end

  test "stored blobs survive a Crypto decrypt with the configured key" do
    key = Quintal.Auth.key()
    {:ok, blob} = Crypto.encrypt(:erlang.term_to_binary(%{tokens: true}), key)

    assert :ok = TokenStore.put(@did, blob, [])

    {:ok, stored} = TokenStore.fetch(@did, [])
    assert {:ok, plaintext} = Crypto.decrypt(stored, key)
    assert :erlang.binary_to_term(plaintext) == %{tokens: true}
  end
end
