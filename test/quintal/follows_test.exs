defmodule Quintal.FollowsTest do
  use Quintal.DataCase, async: true

  import Mox

  alias ProtoRune.Atproto.OAuth.Session
  alias Quintal.Follow
  alias Quintal.Follows
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
    indexa_identidade("did:plc:beto", "beto.bsky.social")

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

  describe "seguir/2" do
    test "escreve o follow no pds e indexa otimista", %{session: session} do
      expect(PDSMock, :create_record, fn _session, "place.quintal.graph.follow", record ->
        assert record["subject"] == "did:plc:beto"
        assert {:ok, _, _} = DateTime.from_iso8601(record["createdAt"])

        {:ok, %{uri: "at://did:plc:alice/place.quintal.graph.follow/f1", cid: "bafy"}}
      end)

      assert {:ok, follow} = Follows.seguir(session, "beto.bsky.social")

      assert follow.seguidor_did == "did:plc:alice"
      assert follow.seguido_did == "did:plc:beto"
      assert follow.uri == "at://did:plc:alice/place.quintal.graph.follow/f1"
      assert Repo.get_by(Follow, uri: follow.uri)
    end

    test "aceita did como identificador", %{session: session} do
      stub(PDSMock, :create_record, fn _session, _collection, _record ->
        {:ok, %{uri: "at://did:plc:alice/place.quintal.graph.follow/f2", cid: "bafy"}}
      end)

      assert {:ok, follow} = Follows.seguir(session, "did:plc:beto")
      assert follow.seguido_did == "did:plc:beto"
    end

    test "canto desconhecido não sai de casa", %{session: session} do
      assert {:error, :canto_desconhecido} = Follows.seguir(session, "ninguem.bsky.social")
      assert Repo.aggregate(Follow, :count) == 0
    end

    test "seguir a si mesma é recusado", %{session: session} do
      assert {:error, :auto_follow} = Follows.seguir(session, "alice.bsky.social")
      assert Repo.aggregate(Follow, :count) == 0
    end

    test "erro do pds não indexa nada", %{session: session} do
      stub(PDSMock, :create_record, fn _session, _collection, _record ->
        {:error, :pds_fora_do_ar}
      end)

      assert {:error, :pds_fora_do_ar} = Follows.seguir(session, "did:plc:beto")
      assert Repo.aggregate(Follow, :count) == 0
    end
  end

  describe "deixar_de_seguir/2" do
    test "apaga do pds e do índice", %{session: session} do
      uri = "at://did:plc:alice/place.quintal.graph.follow/f1"

      {:ok, _} =
        Follows.indexar("did:plc:alice", %{
          uri: uri,
          value: %{subject: "did:plc:beto", created_at: "2026-08-01T10:00:00Z"}
        })

      expect(PDSMock, :delete_record, fn _session, "place.quintal.graph.follow", "f1", _opts ->
        :ok
      end)

      assert :ok = Follows.deixar_de_seguir(session, uri)
      assert Repo.aggregate(Follow, :count) == 0
    end

    test "follow alheio não sai de casa", %{session: session} do
      uri = "at://did:plc:beto/place.quintal.graph.follow/f9"

      assert {:error, :follow_alheio} = Follows.deixar_de_seguir(session, uri)
    end

    test "erro do pds propaga e o índice fica intacto", %{session: session} do
      uri = "at://did:plc:alice/place.quintal.graph.follow/f1"

      {:ok, _} =
        Follows.indexar("did:plc:alice", %{
          uri: uri,
          value: %{subject: "did:plc:beto", created_at: "2026-08-01T10:00:00Z"}
        })

      stub(PDSMock, :delete_record, fn _session, _collection, _rkey, _opts ->
        {:error, :pds_fora_do_ar}
      end)

      assert {:error, :pds_fora_do_ar} = Follows.deixar_de_seguir(session, uri)
      assert Repo.get_by(Follow, uri: uri)
    end
  end

  describe "vizinhanca/1" do
    test "lista quem a pessoa lê, com identidade, sem contadores" do
      {:ok, _} =
        Follows.indexar("did:plc:alice", %{
          uri: "at://did:plc:alice/place.quintal.graph.follow/f1",
          value: %{subject: "did:plc:beto", created_at: "2026-08-01T10:00:00Z"}
        })

      assert [follow] = Follows.vizinhanca("did:plc:alice")
      assert follow.seguido.handle == "beto.bsky.social"
      assert Follows.vizinhanca("did:plc:beto") == []
    end
  end

  describe "mencoes/1" do
    test "handle e nome de exibição de cada canto lido; sem nome, nil" do
      {:ok, _} =
        Follows.indexar("did:plc:alice", %{
          uri: "at://did:plc:alice/place.quintal.graph.follow/f1",
          value: %{subject: "did:plc:beto", created_at: "2026-08-01T10:00:00Z"}
        })

      assert [%{handle: "beto.bsky.social", nome: nil}] = Follows.mencoes("did:plc:alice")

      Repo.insert!(
        Quintal.Canto.changeset(%Quintal.Canto{}, %{
          dono_did: "did:plc:beto",
          nome: "beto",
          tema: "papel",
          blocos: ~w(bio prosas recados quem-eu-leio links),
          updated_at: DateTime.utc_now()
        })
      )

      assert [%{handle: "beto.bsky.social", nome: "beto"}] = Follows.mencoes("did:plc:alice")
      assert Follows.mencoes("did:plc:beto") == []
    end
  end

  describe "indexar/2 e desindexar/1" do
    test "upsert idempotente: o eco do firehose é o mesmo evento" do
      record = %{
        uri: "at://did:plc:alice/place.quintal.graph.follow/f1",
        value: %{"subject" => "did:plc:beto", "createdAt" => "2026-08-01T10:00:00Z"}
      }

      assert {:ok, _} = Follows.indexar("did:plc:alice", record)
      assert {:ok, _} = Follows.indexar("did:plc:alice", record)

      assert Repo.aggregate(Follow, :count) == 1
    end

    test "desindexar remove pelo uri guardado" do
      uri = "at://did:plc:alice/place.quintal.graph.follow/f1"

      {:ok, _} =
        Follows.indexar("did:plc:alice", %{
          uri: uri,
          value: %{subject: "did:plc:beto", created_at: "2026-08-01T10:00:00Z"}
        })

      assert :ok = Follows.desindexar(uri)
      assert Repo.aggregate(Follow, :count) == 0
    end
  end
end
