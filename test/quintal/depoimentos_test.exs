defmodule Quintal.DepoimentosTest do
  use Quintal.DataCase, async: true

  import Mox

  alias ProtoRune.Atproto.OAuth.Session
  alias Quintal.Depoimento
  alias Quintal.Depoimentos
  alias Quintal.PDS.Mock, as: PDSMock
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

  defp indexa_depoimento(uri, texto \\ "pessoa incrivel") do
    Depoimentos.indexar("did:plc:beto", %{
      uri: uri,
      value: %{"subject" => "did:plc:alice", "text" => texto, "createdAt" => "2026-08-01T10:00:00Z"}
    })
  end

  describe "deixar/3" do
    test "escreve o depoimento no pds e indexa otimista, pendente de aceite", %{session: session} do
      expect(PDSMock, :create_record, fn _session, "place.quintal.canto.depoimento", record ->
        assert record["subject"] == "did:plc:beto"
        assert record["text"] == "melhor pessoa dev que conheço"
        assert {:ok, _, _} = DateTime.from_iso8601(record["createdAt"])

        {:ok, %{uri: "at://did:plc:alice/place.quintal.canto.depoimento/d1", cid: "bafy"}}
      end)

      assert {:ok, depoimento} = Depoimentos.deixar(session, "beto.bsky.social", "melhor pessoa dev que conheço")

      assert depoimento.autor_did == "did:plc:alice"
      assert depoimento.subject_did == "did:plc:beto"
      assert depoimento.aceito == nil
      assert Repo.get(Depoimento, depoimento.uri)

      assert Repo.get_by(VisitaEvento, dono_did: "did:plc:beto", tipo: "depoimento", ref_uri: depoimento.uri)
    end

    test "texto vazio não sai de casa", %{session: session} do
      assert {:error, :texto_vazio} = Depoimentos.deixar(session, "did:plc:beto", "")
      assert Repo.aggregate(Depoimento, :count) == 0
    end

    test "canto desconhecido não sai de casa", %{session: session} do
      assert {:error, :canto_desconhecido} = Depoimentos.deixar(session, "ninguem.bsky.social", "oi")
      assert Repo.aggregate(Depoimento, :count) == 0
    end

    test "depoimento no próprio canto é recusado", %{session: session} do
      assert {:error, :depoimento_proprio_canto} = Depoimentos.deixar(session, "did:plc:alice", "eu me amo")
      assert Repo.aggregate(Depoimento, :count) == 0
    end

    test "erro do pds não indexa nada", %{session: session} do
      stub(PDSMock, :create_record, fn _session, _collection, _record ->
        {:error, :pds_fora_do_ar}
      end)

      assert {:error, :pds_fora_do_ar} = Depoimentos.deixar(session, "did:plc:beto", "oi")
      assert Repo.aggregate(Depoimento, :count) == 0
    end
  end

  describe "aceitar/2 e deixar_quieto/2" do
    test "dono do canto aceita e o depoimento aparece", %{session: session} do
      uri = "at://did:plc:beto/place.quintal.canto.depoimento/d1"
      {:ok, _} = indexa_depoimento(uri)

      assert {:ok, aceito} = Depoimentos.aceitar(session, uri)
      assert aceito.aceito == true

      assert [aparece] = Depoimentos.aceitos("did:plc:alice")
      assert aparece.uri == uri
      assert aparece.autor.handle == "beto.bsky.social"
      assert Depoimentos.pendentes("did:plc:alice") == []
    end

    test "dono do canto deixa quieto e o depoimento some das duas listas", %{session: session} do
      uri = "at://did:plc:beto/place.quintal.canto.depoimento/d1"
      {:ok, _} = indexa_depoimento(uri)

      assert {:ok, quieto} = Depoimentos.deixar_quieto(session, uri)
      assert quieto.aceito == false

      assert Depoimentos.aceitos("did:plc:alice") == []
      assert Depoimentos.pendentes("did:plc:alice") == []
    end

    test "depoimento alheio não muda", %{session: session} do
      uri = "at://did:plc:beto/place.quintal.canto.depoimento/d1"
      {:ok, _} = indexa_depoimento(uri)

      outra_sessao = %{session | did: "did:plc:beto", handle: "beto.bsky.social"}

      assert {:error, :depoimento_alheio} = Depoimentos.aceitar(outra_sessao, uri)
      assert {:error, :depoimento_alheio} = Depoimentos.deixar_quieto(outra_sessao, uri)
      assert Repo.get!(Depoimento, uri).aceito == nil
    end
  end

  describe "pendentes/1" do
    test "lista os que esperam decisão, do mais novo para o mais antigo" do
      {:ok, _} = indexa_depoimento("at://did:plc:beto/place.quintal.canto.depoimento/d1", "primeiro")

      {:ok, _} =
        Depoimentos.indexar("did:plc:beto", %{
          uri: "at://did:plc:beto/place.quintal.canto.depoimento/d2",
          value: %{subject: "did:plc:alice", text: "segundo", created_at: "2026-08-02T10:00:00Z"}
        })

      assert [novo, velho] = Depoimentos.pendentes("did:plc:alice")
      assert novo.texto == "segundo"
      assert velho.texto == "primeiro"
    end
  end

  describe "indexar/2 e desindexar/1" do
    test "upsert idempotente: o eco do firehose é o mesmo evento" do
      record = %{
        uri: "at://did:plc:beto/place.quintal.canto.depoimento/d1",
        value: %{"subject" => "did:plc:alice", "text" => "oi", "createdAt" => "2026-08-01T10:00:00Z"}
      }

      assert {:ok, _} = Depoimentos.indexar("did:plc:beto", record)
      assert {:ok, _} = Depoimentos.indexar("did:plc:beto", record)

      assert Repo.aggregate(Depoimento, :count) == 1
      assert Repo.aggregate(VisitaEvento, :count) == 1
    end

    test "re-upsert preserva o aceito e atualiza o texto" do
      uri = "at://did:plc:beto/place.quintal.canto.depoimento/d1"
      {:ok, _} = indexa_depoimento(uri)

      Depoimento |> Repo.get!(uri) |> Ecto.Changeset.change(aceito: true) |> Repo.update!()

      {:ok, depoimento} =
        Depoimentos.indexar("did:plc:beto", %{
          uri: uri,
          value: %{"subject" => "did:plc:alice", "text" => "editado", "createdAt" => "2026-08-01T10:00:00Z"}
        })

      assert depoimento.texto == "editado"
      assert depoimento.aceito == true
    end

    test "desindexar remove o depoimento e o evento de visita" do
      uri = "at://did:plc:beto/place.quintal.canto.depoimento/d1"
      {:ok, _} = indexa_depoimento(uri)

      assert Repo.aggregate(VisitaEvento, :count) == 1
      assert :ok = Depoimentos.desindexar(uri)
      assert Repo.aggregate(Depoimento, :count) == 0
      assert Repo.aggregate(VisitaEvento, :count) == 0
    end
  end
end
