defmodule Quintal.BootstrapTest do
  use Quintal.DataCase, async: true

  import Mox

  alias ProtoRune.Atproto.OAuth.Session
  alias Quintal.Bootstrap
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

    {:ok, session: session}
  end

  defp prosa_value(text, created_at) do
    %{text: text, created_at: created_at}
  end

  test "canto.config existe: não escreve nada, só faz backfill", %{session: session} do
    stub(PDSMock, :get_record, fn _session, "did:plc:alice", "place.quintal.canto.config", "self" ->
      {:ok, %{uri: "at://did:plc:alice/place.quintal.canto.config/self"}}
    end)

    stub(PDSMock, :list_records, fn _session, "did:plc:alice", "place.quintal.feed.prosa", _opts ->
      {:ok,
       %{
         records: [
           %{
             uri: "at://did:plc:alice/place.quintal.feed.prosa/3k",
             cid: "bafy1",
             value: prosa_value("primeira prosa", "2026-08-01T10:00:00Z")
           }
         ]
       }}
    end)

    assert :ok = Bootstrap.run(session)

    identidade = Repo.get!(Quintal.Identidade, "did:plc:alice")
    assert identidade.handle == "alice.bsky.social"
    assert identidade.pds_url == "https://pds.example"

    prosa = Repo.get!(Quintal.Prosa, "at://did:plc:alice/place.quintal.feed.prosa/3k")
    assert prosa.texto == "primeira prosa"
    assert prosa.cid == "bafy1"
    esperado = "2026-08-01T10:00:00Z" |> DateTime.from_iso8601() |> elem(1)
    assert DateTime.compare(prosa.created_at, esperado) == :eq
  end

  test "canto.config ausente: escreve o padrão no pds", %{session: session} do
    stub(PDSMock, :get_record, fn _session, _did, "place.quintal.canto.config", "self" ->
      {:error, :record_not_found}
    end)

    expect(PDSMock, :put_record, fn _session, "place.quintal.canto.config", "self", config, _opts ->
      assert config["tema"] == "papel"
      assert config["blocos"] == ~w(bio prosas recados quem-eu-leio links)
      assert is_binary(config["updatedAt"])

      {:ok, %{uri: "at://x", cid: "bafy"}}
    end)

    stub(PDSMock, :list_records, fn _session, _did, "place.quintal.feed.prosa", _opts ->
      {:ok, %{records: []}}
    end)

    assert :ok = Bootstrap.run(session)
  end

  test "backfill pagina até acabar o cursor", %{session: session} do
    stub(PDSMock, :get_record, fn _session, _did, "place.quintal.canto.config", "self" ->
      {:ok, %{}}
    end)

    expect(PDSMock, :list_records, fn _session, _did, "place.quintal.feed.prosa", [limit: 100] ->
      {:ok,
       %{
         records: [
           %{
             uri: "at://did:plc:alice/place.quintal.feed.prosa/1",
             cid: "c1",
             value: prosa_value("um", "2026-08-01T10:00:00Z")
           }
         ],
         cursor: "pagina-2"
       }}
    end)

    expect(PDSMock, :list_records, fn _session, _did, "place.quintal.feed.prosa", [limit: 100, cursor: "pagina-2"] ->
      {:ok,
       %{
         records: [
           %{
             uri: "at://did:plc:alice/place.quintal.feed.prosa/2",
             cid: "c2",
             value: prosa_value("dois", "2026-08-02T10:00:00Z")
           }
         ]
       }}
    end)

    assert :ok = Bootstrap.run(session)

    assert Repo.get!(Quintal.Prosa, "at://did:plc:alice/place.quintal.feed.prosa/1").texto == "um"
    assert Repo.get!(Quintal.Prosa, "at://did:plc:alice/place.quintal.feed.prosa/2").texto == "dois"
  end

  test "falha no pds vira log, nunca exceção", %{session: session} do
    stub(PDSMock, :get_record, fn _session, _did, _collection, _rkey ->
      {:error, :pds_fora_do_ar}
    end)

    stub(PDSMock, :put_record, fn _session, _collection, _rkey, _record, _opts ->
      {:error, :pds_fora_do_ar}
    end)

    assert :ok = Bootstrap.run(session)
  end
end
