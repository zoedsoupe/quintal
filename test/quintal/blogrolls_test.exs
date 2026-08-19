defmodule Quintal.BlogrollsTest do
  use Quintal.DataCase, async: true

  import Mox

  alias ProtoRune.Atproto.OAuth.Session
  alias Quintal.Blogroll
  alias Quintal.Blogrolls
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
    indexa_identidade("did:plc:carol", "carol.bsky.social")

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

  describe "atualizar/2" do
    test "escreve o record no pds e indexa otimista", %{session: session} do
      expect(PDSMock, :put_record, fn _session, "place.quintal.canto.blogroll", "self", record, _opts ->
        assert record["items"] == [
                 %{"did" => "did:plc:beto", "note" => "elixir e quintal"},
                 %{"did" => "did:plc:carol"}
               ]

        assert {:ok, _, _} = DateTime.from_iso8601(record["updatedAt"])

        {:ok, %{uri: "at://did:plc:alice/place.quintal.canto.blogroll/self", cid: "bafy"}}
      end)

      assert {:ok, blogroll} =
               Blogrolls.atualizar(session, [
                 %{did: "did:plc:beto", note: "elixir e quintal"},
                 %{"did" => "did:plc:carol"}
               ])

      assert blogroll.dono_did == "did:plc:alice"
      assert [beto, carol] = blogroll.items
      assert beto.did == "did:plc:beto"
      assert beto.note == "elixir e quintal"
      assert carol.did == "did:plc:carol"
      assert carol.note == nil
    end

    test "canto desconhecido na lista não sai de casa", %{session: session} do
      assert {:error, :canto_desconhecido} =
               Blogrolls.atualizar(session, [%{did: "did:plc:ninguem", note: "quem"}])

      assert Repo.aggregate(Blogroll, :count) == 0
    end

    test "erro do pds não indexa nada", %{session: session} do
      stub(PDSMock, :put_record, fn _session, _collection, _rkey, _record, _opts ->
        {:error, :pds_fora_do_ar}
      end)

      assert {:error, :pds_fora_do_ar} = Blogrolls.atualizar(session, [%{did: "did:plc:beto"}])
      assert Repo.aggregate(Blogroll, :count) == 0
    end
  end

  describe "get/1" do
    test "nil quando a pessoa ainda não montou o blogroll" do
      assert Blogrolls.get("did:plc:alice") == nil
    end

    test "volta com a identidade do dono", %{session: session} do
      stub(PDSMock, :put_record, fn _session, _collection, _rkey, _record, _opts ->
        {:ok, %{uri: "at://did:plc:alice/place.quintal.canto.blogroll/self", cid: "bafy"}}
      end)

      {:ok, _} = Blogrolls.atualizar(session, [%{did: "did:plc:beto"}])

      assert blogroll = Blogrolls.get("did:plc:alice")
      assert blogroll.dono.handle == "alice.bsky.social"
    end
  end

  describe "indexar/2" do
    test "upsert idempotente: o eco do firehose é o mesmo evento" do
      value = %{
        "items" => [%{"did" => "did:plc:beto", "note" => "amiga"}],
        "updatedAt" => "2026-08-01T10:00:00Z"
      }

      assert {:ok, _} = Blogrolls.indexar("did:plc:alice", %{value: value})
      assert {:ok, _} = Blogrolls.indexar("did:plc:alice", %{value: value})

      assert Repo.aggregate(Blogroll, :count) == 1
    end

    test "re-upsert substitui a lista inteira" do
      {:ok, _} =
        Blogrolls.indexar("did:plc:alice", %{
          value: %{"items" => [%{"did" => "did:plc:beto"}], "updatedAt" => "2026-08-01T10:00:00Z"}
        })

      {:ok, blogroll} =
        Blogrolls.indexar("did:plc:alice", %{
          value: %{items: [%{did: "did:plc:carol"}], updated_at: "2026-08-02T10:00:00Z"}
        })

      assert [item] = blogroll.items
      assert item.did == "did:plc:carol"
      assert Repo.aggregate(Blogroll, :count) == 1
    end
  end
end
