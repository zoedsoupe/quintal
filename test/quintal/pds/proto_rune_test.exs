defmodule Quintal.PDS.ProtoRuneTest do
  use ExUnit.Case, async: true

  import Mox

  alias ProtoRune.Atproto.OAuth.DPoP
  alias ProtoRune.Atproto.OAuth.Session
  alias Quintal.HTTPMock
  alias Quintal.PDS.ProtoRune, as: PDS

  setup :verify_on_exit!

  setup do
    {dpop_key, dpop_jwk} = DPoP.generate_key()

    session = %Session{
      did: "did:plc:alice",
      handle: "alice.bsky.social",
      access_token: "token-abc",
      dpop_key: dpop_key,
      dpop_jwk: dpop_jwk,
      service_url: "https://pds.example"
    }

    {:ok, session: session}
  end

  defp ok_json(body), do: {:ok, %{status: 200, body: body, headers: []}}

  describe "create_record/3" do
    test "escreve no pds da pessoa, assinado com DPoP, e injeta $type", %{session: session} do
      expect(HTTPMock, :request, fn :post, url, opts ->
        assert url == "https://pds.example/xrpc/com.atproto.repo.createRecord"

        headers = Map.new(opts[:headers])
        assert headers["authorization"] == "DPoP token-abc"
        assert is_binary(headers["dpop"])

        body = opts[:json]
        assert body.repo == "did:plc:alice"
        assert body.collection == "place.quintal.feed.prosa"
        assert body.record[:"$type"] == "place.quintal.feed.prosa"
        assert body.record.text == "bom dia"

        ok_json(~s({"uri":"at://did:plc:alice/place.quintal.feed.prosa/3k","cid":"bafy"}))
      end)

      prosa = %{"text" => "bom dia", "createdAt" => "2026-08-18T12:00:00Z"}

      assert {:ok, %{uri: "at://did:plc:alice/place.quintal.feed.prosa/3k", cid: "bafy"}} =
               PDS.create_record(session, "place.quintal.feed.prosa", prosa)
    end

    test "record inválido falha em casa, sem tocar a rede", %{session: session} do
      # nenhuma expectativa no mock: qualquer chamada HTTP derruba o teste
      assert {:error, errors} = PDS.create_record(session, "place.quintal.feed.prosa", %{})
      assert Enum.any?(errors, &String.contains?(&1, "missing required field"))
    end
  end

  describe "get_record/4" do
    test "monta a query com repo, collection e rkey", %{session: session} do
      expect(HTTPMock, :request, fn :get, url, _opts ->
        assert url =~ "com.atproto.repo.getRecord"
        assert url =~ "repo=did%3Aplc%3Aalice"
        assert url =~ "collection=place.quintal.feed.prosa"
        assert url =~ "rkey=3k"

        ok_json(~s({"uri":"at://x","cid":"bafy","value":{"text":"oi"}}))
      end)

      assert {:ok, %{uri: "at://x", value: %{text: "oi"}}} =
               PDS.get_record(session, "did:plc:alice", "place.quintal.feed.prosa", "3k")
    end
  end

  describe "list_records/4" do
    test "repassa limit e cursor", %{session: session} do
      expect(HTTPMock, :request, fn :get, url, _opts ->
        assert url =~ "limit=10"
        assert url =~ "cursor=abc"

        ok_json(~s({"records":[],"cursor":"def"}))
      end)

      assert {:ok, %{records: [], cursor: "def"}} =
               PDS.list_records(session, "did:plc:alice", "place.quintal.feed.prosa",
                 limit: 10,
                 cursor: "abc"
               )
    end
  end

  describe "put_record/5" do
    test "inclui swapCommit quando pedido", %{session: session} do
      expect(HTTPMock, :request, fn :post, _url, opts ->
        assert opts[:json].rkey == "self"
        assert opts[:json].swapCommit == "bafy-antigo"

        ok_json(~s({"uri":"at://x","cid":"bafy-novo"}))
      end)

      config = %{"tema" => "papel", "blocos" => ["bio"], "updatedAt" => "2026-08-18T12:00:00Z"}

      assert {:ok, %{cid: "bafy-novo"}} =
               PDS.put_record(session, "place.quintal.canto.config", "self", config, swap_commit: "bafy-antigo")
    end
  end

  describe "delete_record/4" do
    test "retorna :ok no sucesso", %{session: session} do
      expect(HTTPMock, :request, fn :post, url, opts ->
        assert url =~ "com.atproto.repo.deleteRecord"
        assert opts[:json].rkey == "3k"

        ok_json(~s({}))
      end)

      assert :ok = PDS.delete_record(session, "place.quintal.feed.prosa", "3k")
    end
  end

  describe "upload_blob/3" do
    test "sobe o binário cru com o content-type preservado", %{session: session} do
      expect(HTTPMock, :request, fn :post, url, opts ->
        assert url =~ "com.atproto.repo.uploadBlob"
        assert opts[:body] == <<0, 1, 2, 3>>
        assert {"content-type", "image/webp"} in opts[:headers]

        ok_json(~s({"blob":{"$type":"blob","ref":{"$link":"bafy"},"mimeType":"image/webp","size":4}}))
      end)

      assert {:ok, %{blob: %{mime_type: "image/webp"}}} =
               PDS.upload_blob(session, <<0, 1, 2, 3>>, "image/webp")
    end
  end

  describe "erros do pds" do
    test "status de erro vira {:error, _}", %{session: session} do
      expect(HTTPMock, :request, fn :get, _url, _opts ->
        {:ok, %Req.Response{status: 400, body: ~s({"error":"RecordNotFound","message":"x"}), headers: %{}}}
      end)

      assert {:error, _} =
               PDS.get_record(session, "did:plc:alice", "place.quintal.feed.prosa", "nada")
    end
  end
end
