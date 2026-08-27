defmodule Quintal.CantosTest do
  use Quintal.DataCase, async: true

  import Mox

  alias ProtoRune.Atproto.OAuth.Session
  alias Quintal.Canto
  alias Quintal.Cantos
  alias Quintal.PDS.Mock, as: PDSMock
  alias Quintal.Repo

  setup :verify_on_exit!

  setup do
    session = %Session{
      did: "did:plc:alice",
      handle: "alice.bsky.social",
      access_token: "token-abc",
      dpop_key: "key",
      dpop_jwk: %{},
      service_url: "https://pds.example"
    }

    indexa_identidade("did:plc:alice", "alice.bsky.social")

    {:ok, session: session}
  end

  defp indexa_identidade(did, handle) do
    Repo.insert!(%Quintal.Identidade{
      did: did,
      handle: handle,
      pds_url: "https://pds.example",
      atualizado_em: DateTime.utc_now()
    })
  end

  describe "arrumar/2" do
    test "canto novo cai no padrão: tema papel, todos os blocos", %{session: session} do
      expect(PDSMock, :put_record, fn _session, "place.quintal.canto.config", "self", record, _opts ->
        assert record["tema"] == "papel"
        assert record["blocos"] == ~w(bio prosas recados quem-eu-leio links)
        refute Map.has_key?(record, "cor")
        assert {:ok, _, _} = DateTime.from_iso8601(record["updatedAt"])

        {:ok, %{uri: "at://did:plc:alice/place.quintal.canto.config/self", cid: "bafy"}}
      end)

      assert {:ok, canto} = Cantos.arrumar(session, %{bio: "escrevo sobre elixir"})
      assert canto.tema == "papel"
      assert canto.bio == "escrevo sobre elixir"
    end

    test "mescla sobre a configuração atual", %{session: session} do
      {:ok, _} =
        Cantos.indexar("did:plc:alice", %{
          value: %{
            "tema" => "madrugada",
            "blocos" => ~w(prosas recados),
            "bio" => "coruja",
            "updatedAt" => "2026-08-01T10:00:00Z"
          }
        })

      expect(PDSMock, :put_record, fn _session, "place.quintal.canto.config", "self", record, _opts ->
        assert record["tema"] == "madrugada"
        assert record["blocos"] == ~w(prosas recados)
        assert record["bio"] == "coruja"
        assert record["cor"] == "#ff6fb5"

        {:ok, %{uri: "at://did:plc:alice/place.quintal.canto.config/self", cid: "bafy"}}
      end)

      assert {:ok, canto} = Cantos.arrumar(session, %{cor: "#ff6fb5"})
      assert canto.tema == "madrugada"
      assert canto.cor == "#ff6fb5"
      assert canto.bio == "coruja"
    end

    test "cor vazia tira o acento do record", %{session: session} do
      {:ok, _} =
        Cantos.indexar("did:plc:alice", %{
          value: %{
            "tema" => "gloss",
            "cor" => "#ff6fb5",
            "blocos" => ~w(bio prosas),
            "updatedAt" => "2026-08-01T10:00:00Z"
          }
        })

      expect(PDSMock, :put_record, fn _session, "place.quintal.canto.config", "self", record, _opts ->
        refute Map.has_key?(record, "cor")
        assert record["tema"] == "gloss"

        {:ok, %{uri: "at://did:plc:alice/place.quintal.canto.config/self", cid: "bafy"}}
      end)

      assert {:ok, canto} = Cantos.arrumar(session, %{"cor" => ""})
      assert canto.cor == nil
    end

    test "aceita chaves string", %{session: session} do
      stub(PDSMock, :put_record, fn _session, _collection, _rkey, _record, _opts ->
        {:ok, %{uri: "at://did:plc:alice/place.quintal.canto.config/self", cid: "bafy"}}
      end)

      assert {:ok, canto} = Cantos.arrumar(session, %{"tema" => "gloss", "blocos" => ~w(bio links)})
      assert canto.tema == "gloss"
      assert canto.blocos == ~w(bio links)
    end

    test "tema fora dos presets falha em casa, antes da rede", %{session: session} do
      assert {:error, changeset} = Cantos.arrumar(session, %{tema: "neon"})
      assert errors_on(changeset).tema != []
      assert Repo.aggregate(Canto, :count) == 0
    end

    test "bloco desconhecido falha em casa", %{session: session} do
      assert {:error, changeset} = Cantos.arrumar(session, %{blocos: ~w(bio mural)})
      assert errors_on(changeset).blocos != []
      assert Repo.aggregate(Canto, :count) == 0
    end

    test "avatar entra no record e volta pro índice", %{session: session} do
      blob = %{"$type" => "blob", "ref" => %{"$link" => "bafyfoto"}, "mimeType" => "image/png", "size" => 1234}

      expect(PDSMock, :put_record, fn _session, "place.quintal.canto.config", "self", record, _opts ->
        assert record["avatar"] == blob
        {:ok, %{uri: "at://did:plc:alice/place.quintal.canto.config/self", cid: "bafy"}}
      end)

      assert {:ok, canto} = Cantos.arrumar(session, %{avatar: blob})
      assert canto.avatar == blob
      assert Cantos.avatars(["did:plc:alice"]) == %{"did:plc:alice" => blob}
    end

    test "avatar nil tira a foto do record", %{session: session} do
      blob = %{"$type" => "blob", "ref" => %{"$link" => "bafyfoto"}, "mimeType" => "image/png", "size" => 1234}

      {:ok, _} =
        Cantos.indexar("did:plc:alice", %{
          value: %{
            "tema" => "papel",
            "blocos" => ~w(prosas),
            "avatar" => blob,
            "updatedAt" => "2026-08-01T10:00:00Z"
          }
        })

      expect(PDSMock, :put_record, fn _session, "place.quintal.canto.config", "self", record, _opts ->
        refute Map.has_key?(record, "avatar")
        {:ok, %{uri: "at://did:plc:alice/place.quintal.canto.config/self", cid: "bafy"}}
      end)

      assert {:ok, canto} = Cantos.arrumar(session, %{avatar: nil})
      assert canto.avatar == nil
      assert Cantos.avatars(["did:plc:alice"]) == %{}
    end

    test "erro do pds não indexa nada", %{session: session} do
      stub(PDSMock, :put_record, fn _session, _collection, _rkey, _record, _opts ->
        {:error, :pds_fora_do_ar}
      end)

      assert {:error, :pds_fora_do_ar} = Cantos.arrumar(session, %{tema: "gloss"})
      assert Repo.aggregate(Canto, :count) == 0
    end
  end

  describe "get/1 e indexar/2" do
    test "nil quando o canto nunca foi indexado" do
      assert Cantos.get("did:plc:alice") == nil
    end

    test "volta com a identidade do dono" do
      {:ok, _} =
        Cantos.indexar("did:plc:alice", %{
          value: %{"tema" => "papel", "blocos" => ~w(bio prosas), "updatedAt" => "2026-08-01T10:00:00Z"}
        })

      assert canto = Cantos.get("did:plc:alice")
      assert canto.dono.handle == "alice.bsky.social"
    end

    test "upsert idempotente: o eco do firehose é o mesmo evento" do
      value = %{
        "tema" => "madrugada",
        "blocos" => ~w(bio prosas),
        "links" => [%{"titulo" => "site", "url" => "https://exemplo.com"}],
        "updatedAt" => "2026-08-01T10:00:00Z"
      }

      assert {:ok, _} = Cantos.indexar("did:plc:alice", %{value: value})
      assert {:ok, canto} = Cantos.indexar("did:plc:alice", %{value: value})

      assert Repo.aggregate(Canto, :count) == 1
      assert [%{titulo: "site", url: "https://exemplo.com"}] = canto.links
    end

    test "re-upsert substitui a configuração" do
      {:ok, _} =
        Cantos.indexar("did:plc:alice", %{
          value: %{"tema" => "papel", "blocos" => ~w(bio), "updatedAt" => "2026-08-01T10:00:00Z"}
        })

      {:ok, canto} =
        Cantos.indexar("did:plc:alice", %{
          value: %{tema: "gloss", cor: "#57c9d8", blocos: ~w(prosas), updated_at: "2026-08-02T10:00:00Z"}
        })

      assert canto.tema == "gloss"
      assert canto.cor == "#57c9d8"
      assert canto.blocos == ~w(prosas)
      assert Repo.aggregate(Canto, :count) == 1
    end
  end
end
