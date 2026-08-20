defmodule Quintal.VisitasTest do
  use Quintal.DataCase, async: true

  alias Quintal.Repo
  alias Quintal.VisitaEvento
  alias Quintal.Visitas

  setup do
    indexa_identidade("did:plc:alice", "alice.bsky.social")
    indexa_identidade("did:plc:beto", "beto.bsky.social")
    indexa_identidade("did:plc:carol", "carol.bsky.social")

    :ok
  end

  defp indexa_identidade(did, handle) do
    Repo.insert!(%Quintal.Identidade{
      did: did,
      handle: handle,
      pds_url: "https://pds.example",
      atualizado_em: DateTime.utc_now()
    })
  end

  describe "registrar/4" do
    test "dedupa por (tipo, ref_uri, autor_did): escrita otimista e eco contam uma vez" do
      assert :ok = Visitas.registrar("did:plc:alice", "recado", "at://x/1", "did:plc:beto")
      assert :ok = Visitas.registrar("did:plc:alice", "recado", "at://x/1", "did:plc:beto")

      assert Repo.aggregate(VisitaEvento, :count) == 1
    end

    test "leituras: cada pessoa deixa uma marca na mesma prosa" do
      assert :ok = Visitas.registrar("did:plc:alice", "leitura", "at://x/1", "did:plc:beto")
      assert :ok = Visitas.registrar("did:plc:alice", "leitura", "at://x/1", "did:plc:carol")
      assert :ok = Visitas.registrar("did:plc:alice", "leitura", "at://x/1", "did:plc:beto")

      assert Repo.aggregate(VisitaEvento, :count) == 2
      assert Visitas.leitura_marcada?("at://x/1", "did:plc:beto") == true
      assert Visitas.leitura_marcada?("at://x/2", "did:plc:beto") == false
    end

    test "visita da própria pessoa no próprio canto nunca registra" do
      assert :ok = Visitas.registrar("did:plc:alice", "recado", "at://x/1", "did:plc:alice")
      assert Repo.aggregate(VisitaEvento, :count) == 0
    end
  end

  describe "resumo/1" do
    test "conta por tipo desde a última passada" do
      Visitas.registrar("did:plc:alice", "recado", "at://x/1", "did:plc:beto")
      Visitas.registrar("did:plc:alice", "recado", "at://x/2", "did:plc:carol")
      Visitas.registrar("did:plc:alice", "resposta", "at://x/3", "did:plc:beto")
      Visitas.registrar("did:plc:alice", "novo_leitor", "at://x/4", "did:plc:carol")

      assert Visitas.resumo("did:plc:alice") == %{
               recado: 2,
               resposta: 1,
               novo_leitor: 1,
               depoimento: 0,
               leitura: 0
             }
    end

    test "marcar_lido zera o resumo e apaga a bolinha" do
      Visitas.registrar("did:plc:alice", "recado", "at://x/1", "did:plc:beto")

      assert Visitas.novidade?("did:plc:alice") == true
      assert :ok = Visitas.marcar_lido("did:plc:alice")

      assert Visitas.resumo("did:plc:alice") == %{
               recado: 0,
               resposta: 0,
               novo_leitor: 0,
               depoimento: 0,
               leitura: 0
             }

      assert Visitas.novidade?("did:plc:alice") == false

      Visitas.registrar("did:plc:alice", "depoimento", "at://x/2", "did:plc:carol")
      assert Visitas.novidade?("did:plc:alice") == true

      assert Visitas.resumo("did:plc:alice") == %{
               recado: 0,
               resposta: 0,
               novo_leitor: 0,
               depoimento: 1,
               leitura: 0
             }
    end

    test "quem nunca passou pela página vê tudo desde sempre" do
      Visitas.registrar("did:plc:alice", "novo_leitor", "at://x/1", "did:plc:beto")

      assert Visitas.resumo("did:plc:alice").novo_leitor == 1
      assert Visitas.novidade?("did:plc:alice") == true
    end
  end

  describe "eventos_desde_ultima/1" do
    test "lista do mais novo para o mais antigo, com quem passou" do
      Visitas.registrar("did:plc:alice", "recado", "at://x/1", "did:plc:beto")
      Visitas.registrar("did:plc:alice", "recado", "at://x/2", "did:plc:carol")

      assert [novo, velho] = Visitas.eventos_desde_ultima("did:plc:alice")
      assert novo.ref_uri == "at://x/2"
      assert novo.autor.handle == "carol.bsky.social"
      assert velho.autor.handle == "beto.bsky.social"
    end

    test "marcar_lido esvazia a lista" do
      Visitas.registrar("did:plc:alice", "recado", "at://x/1", "did:plc:beto")
      :ok = Visitas.marcar_lido("did:plc:alice")

      assert Visitas.eventos_desde_ultima("did:plc:alice") == []
    end
  end
end
