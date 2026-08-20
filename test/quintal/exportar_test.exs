defmodule Quintal.ExportarTest do
  use Quintal.DataCase, async: true

  alias Quintal.Exportar
  alias Quintal.Identidade
  alias Quintal.Repo

  defp identidade(did, handle) do
    Repo.insert!(%Identidade{
      did: did,
      handle: handle,
      pds_url: "https://pds.example",
      atualizado_em: DateTime.utc_now()
    })
  end

  test "o zip traz a prosa em markdown e os records em json" do
    identidade("did:plc:alice", "alice.test")
    identidade("did:plc:beto", "beto.test")

    Repo.insert!(%Quintal.Prosa{
      uri: "at://did:plc:alice/place.quintal.feed.prosa/abc123",
      autor_did: "did:plc:alice",
      cid: "bafy",
      texto: "café coado e uma prosa nova",
      tipo: "nota",
      created_at: ~U[2026-08-19 10:00:00.000000Z],
      indexed_at: ~U[2026-08-19 10:00:01.000000Z]
    })

    Repo.insert!(%Quintal.Recado{
      uri: "at://did:plc:alice/place.quintal.canto.recado/xyz",
      autor_did: "did:plc:alice",
      subject_did: "did:plc:beto",
      texto: "passeei aqui",
      created_at: ~U[2026-08-19 11:00:00.000000Z]
    })

    Repo.insert!(%Quintal.Follow{
      uri: "at://did:plc:alice/place.quintal.graph.follow/f1",
      seguidor_did: "did:plc:alice",
      seguido_did: "did:plc:beto",
      created_at: ~U[2026-08-19 09:00:00.000000Z]
    })

    assert {:ok, zip} = Exportar.zip("did:plc:alice")
    assert {:ok, entradas} = :zip.unzip(zip, [:memory])

    mapa = Map.new(entradas, fn {nome, binario} -> {to_string(nome), binario} end)

    assert mapa["prosas/2026-08-19-abc123.md"] == "café coado e uma prosa nova"

    assert [%{"text" => "café coado e uma prosa nova", "uri" => uri}] =
             mapa |> Map.fetch!("records/prosas.json") |> JSON.decode!()

    assert uri == "at://did:plc:alice/place.quintal.feed.prosa/abc123"

    assert [%{"text" => "passeei aqui", "subject" => "did:plc:beto"}] =
             mapa |> Map.fetch!("records/recados.json") |> JSON.decode!()

    assert [%{"subject" => "did:plc:beto"}] =
             mapa |> Map.fetch!("records/follows.json") |> JSON.decode!()

    assert Map.has_key?(mapa, "records/canto.json")
    assert Map.has_key?(mapa, "records/blogroll.json")
    assert Map.has_key?(mapa, "records/depoimentos.json")
  end
end
