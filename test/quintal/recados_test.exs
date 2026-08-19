defmodule Quintal.RecadosTest do
  use Quintal.DataCase, async: true

  import Mox

  alias ProtoRune.Atproto.OAuth.Session
  alias Quintal.PDS.Mock, as: PDSMock
  alias Quintal.Recado
  alias Quintal.Recados
  alias Quintal.Repo
  alias Quintal.VisitaEvento

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

  defp indexa_recado(uri) do
    Recados.indexar("did:plc:beto", %{
      uri: uri,
      value: %{"subject" => "did:plc:alice", "text" => "oi alice", "createdAt" => "2026-08-01T10:00:00Z"}
    })
  end

  describe "deixar/3" do
    test "escreve o recado no pds e indexa otimista", %{session: session} do
      expect(PDSMock, :create_record, fn _session, "place.quintal.canto.recado", record ->
        assert record["subject"] == "did:plc:beto"
        assert record["text"] == "adorei seu canto"
        assert {:ok, _, _} = DateTime.from_iso8601(record["createdAt"])

        {:ok, %{uri: "at://did:plc:alice/place.quintal.canto.recado/r1", cid: "bafy"}}
      end)

      assert {:ok, recado} = Recados.deixar(session, "beto.bsky.social", "adorei seu canto")

      assert recado.autor_did == "did:plc:alice"
      assert recado.subject_did == "did:plc:beto"
      assert recado.oculto == false
      assert Repo.get(Recado, recado.uri)

      # o dono do canto fica sabendo na página visitas
      assert Repo.get_by(VisitaEvento, dono_did: "did:plc:beto", tipo: "recado", ref_uri: recado.uri)
    end

    test "texto vazio não sai de casa", %{session: session} do
      assert {:error, :texto_vazio} = Recados.deixar(session, "did:plc:beto", "   ")
      assert Repo.aggregate(Recado, :count) == 0
    end

    test "canto desconhecido não sai de casa", %{session: session} do
      assert {:error, :canto_desconhecido} = Recados.deixar(session, "ninguem.bsky.social", "oi")
      assert Repo.aggregate(Recado, :count) == 0
    end

    test "recado no próprio canto é recusado", %{session: session} do
      assert {:error, :recado_proprio_canto} = Recados.deixar(session, "alice.bsky.social", "oi eu")
      assert Repo.aggregate(Recado, :count) == 0
    end

    test "erro do pds não indexa nada", %{session: session} do
      stub(PDSMock, :create_record, fn _session, _collection, _record ->
        {:error, :pds_fora_do_ar}
      end)

      assert {:error, :pds_fora_do_ar} = Recados.deixar(session, "did:plc:beto", "oi")
      assert Repo.aggregate(Recado, :count) == 0
    end
  end

  describe "ocultar/2 e mostrar/2" do
    test "dono do canto oculta e mostra de volta", %{session: session} do
      uri = "at://did:plc:beto/place.quintal.canto.recado/r1"
      {:ok, _} = indexa_recado(uri)

      assert {:ok, oculto} = Recados.ocultar(session, uri)
      assert oculto.oculto == true

      assert {:ok, visivel} = Recados.mostrar(session, uri)
      assert visivel.oculto == false
    end

    test "recado fora do próprio canto não muda", %{session: session} do
      uri = "at://did:plc:alice/place.quintal.canto.recado/r2"

      {:ok, _} =
        Recados.indexar("did:plc:alice", %{
          uri: uri,
          value: %{"subject" => "did:plc:beto", "text" => "oi beto", "createdAt" => "2026-08-01T10:00:00Z"}
        })

      assert {:error, :recado_fora_do_canto} = Recados.ocultar(session, uri)
      assert Repo.get!(Recado, uri).oculto == false
    end

    test "uri desconhecida é recado fora do canto", %{session: session} do
      assert {:error, :recado_fora_do_canto} = Recados.ocultar(session, "at://did:plc:beto/place.quintal.canto.recado/r9")
    end
  end

  describe "listar_por_canto/2" do
    test "dono vê os ocultos, visitante não" do
      {:ok, _} = indexa_recado("at://did:plc:beto/place.quintal.canto.recado/r1")

      {:ok, _} =
        Recados.indexar("did:plc:beto", %{
          uri: "at://did:plc:beto/place.quintal.canto.recado/r2",
          value: %{subject: "did:plc:alice", text: "segundo", created_at: "2026-08-02T10:00:00Z"}
        })

      Recado
      |> Repo.get!("at://did:plc:beto/place.quintal.canto.recado/r1")
      |> Ecto.Changeset.change(oculto: true)
      |> Repo.update!()

      # mais novo primeiro, com a identidade de quem escreveu
      assert [novo, velho] = Recados.listar_por_canto("did:plc:alice", "did:plc:alice")
      assert novo.texto == "segundo"
      assert novo.autor.handle == "beto.bsky.social"
      assert velho.oculto == true

      assert [visivel] = Recados.listar_por_canto("did:plc:alice", "did:plc:beto")
      assert visivel.texto == "segundo"
    end
  end

  describe "indexar/2 e desindexar/1" do
    test "upsert idempotente: o eco do firehose é o mesmo evento" do
      record = %{
        uri: "at://did:plc:beto/place.quintal.canto.recado/r1",
        value: %{"subject" => "did:plc:alice", "text" => "oi alice", "createdAt" => "2026-08-01T10:00:00Z"}
      }

      assert {:ok, _} = Recados.indexar("did:plc:beto", record)
      assert {:ok, _} = Recados.indexar("did:plc:beto", record)

      assert Repo.aggregate(Recado, :count) == 1
      assert Repo.aggregate(VisitaEvento, :count) == 1
    end

    test "re-upsert preserva o oculto e atualiza o texto" do
      uri = "at://did:plc:beto/place.quintal.canto.recado/r1"
      {:ok, _} = indexa_recado(uri)

      Recado |> Repo.get!(uri) |> Ecto.Changeset.change(oculto: true) |> Repo.update!()

      {:ok, recado} =
        Recados.indexar("did:plc:beto", %{
          uri: uri,
          value: %{"subject" => "did:plc:alice", "text" => "editado", "createdAt" => "2026-08-01T10:00:00Z"}
        })

      assert recado.texto == "editado"
      assert recado.oculto == true
    end

    test "recado no próprio canto não vira evento de visita" do
      {:ok, _} =
        Recados.indexar("did:plc:alice", %{
          uri: "at://did:plc:alice/place.quintal.canto.recado/r1",
          value: %{"subject" => "did:plc:alice", "text" => "eu", "createdAt" => "2026-08-01T10:00:00Z"}
        })

      assert Repo.aggregate(VisitaEvento, :count) == 0
    end

    test "desindexar remove o recado e o evento de visita" do
      uri = "at://did:plc:beto/place.quintal.canto.recado/r1"
      {:ok, _} = indexa_recado(uri)

      assert Repo.aggregate(VisitaEvento, :count) == 1
      assert :ok = Recados.desindexar(uri)
      assert Repo.aggregate(Recado, :count) == 0
      assert Repo.aggregate(VisitaEvento, :count) == 0
    end
  end
end
