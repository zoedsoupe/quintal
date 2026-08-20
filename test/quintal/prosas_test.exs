defmodule Quintal.ProsasTest do
  use Quintal.DataCase, async: true

  import Mox

  alias ProtoRune.Atproto.OAuth.Session
  alias Quintal.PDS.Mock, as: PDSMock
  alias Quintal.Prosa
  alias Quintal.Prosas
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

  defp indexa_identidade(did \\ "did:plc:alice") do
    Repo.insert!(%Quintal.Identidade{
      did: did,
      handle: did,
      pds_url: "https://pds.example",
      atualizado_em: DateTime.utc_now()
    })
  end

  describe "prosear/2" do
    test "escreve no pds e indexa otimista", %{session: session} do
      indexa_identidade()

      expect(PDSMock, :create_record, fn _session, "place.quintal.feed.prosa", record ->
        assert record["text"] == "bom dia, quintal"
        assert {:ok, _, _} = DateTime.from_iso8601(record["createdAt"])

        {:ok, %{uri: "at://did:plc:alice/place.quintal.feed.prosa/abc", cid: "bafy1"}}
      end)

      assert {:ok, prosa} = Prosas.prosear(session, "bom dia, quintal")

      assert prosa.uri == "at://did:plc:alice/place.quintal.feed.prosa/abc"
      assert prosa.cid == "bafy1"
      assert prosa.texto == "bom dia, quintal"
      assert prosa.autor_did == "did:plc:alice"
      assert Repo.get!(Prosa, prosa.uri).texto == "bom dia, quintal"
    end

    test "texto em branco falha em casa, sem tocar no pds", %{session: session} do
      assert {:error, :texto_vazio} = Prosas.prosear(session, "   ")
      assert Repo.aggregate(Prosa, :count) == 0
    end

    test "markdown vira facets no record", %{session: session} do
      indexa_identidade()

      expect(PDSMock, :create_record, fn _session, "place.quintal.feed.prosa", record ->
        assert [facet] = record["facets"]

        assert facet["index"] == %{"byteStart" => 2, "byteEnd" => 6}
        assert [%{"$type" => "place.quintal.richtext.facet#bold"}] = facet["features"]

        {:ok, %{uri: "at://did:plc:alice/place.quintal.feed.prosa/fac", cid: "bafy2"}}
      end)

      assert {:ok, _prosa} = Prosas.prosear(session, "**bold** dia")
    end

    test "texto sem markdown sai sem facets", %{session: session} do
      indexa_identidade()

      expect(PDSMock, :create_record, fn _session, "place.quintal.feed.prosa", record ->
        refute Map.has_key?(record, "facets")

        {:ok, %{uri: "at://did:plc:alice/place.quintal.feed.prosa/sem", cid: "bafy3"}}
      end)

      assert {:ok, _prosa} = Prosas.prosear(session, "bom dia, quintal")
    end

    test "tipo vai pro record quando é um valor conhecido", %{session: session} do
      indexa_identidade()

      expect(PDSMock, :create_record, fn _session, _collection, record ->
        assert record["tipo"] == "pergunta"
        {:ok, %{uri: "at://did:plc:alice/place.quintal.feed.prosa/p", cid: "bafy"}}
      end)

      assert {:ok, prosa} = Prosas.prosear(session, "alguém aí lê fraunces?", "pergunta")
      assert prosa.tipo == "pergunta"
    end

    test "tipo desconhecido fica fora do record", %{session: session} do
      indexa_identidade()

      expect(PDSMock, :create_record, fn _session, _collection, record ->
        refute Map.has_key?(record, "tipo")
        {:ok, %{uri: "at://did:plc:alice/place.quintal.feed.prosa/s", cid: "bafy"}}
      end)

      assert {:ok, prosa} = Prosas.prosear(session, "sem tipo", "poema")
      assert prosa.tipo == nil
    end

    test "erro do pds não indexa nada", %{session: session} do
      indexa_identidade()

      stub(PDSMock, :create_record, fn _session, _collection, _record ->
        {:error, :pds_fora_do_ar}
      end)

      assert {:error, :pds_fora_do_ar} = Prosas.prosear(session, "oi")
      assert Repo.aggregate(Prosa, :count) == 0
    end
  end

  describe "apagar/2" do
    test "apaga do pds e do índice", %{session: session} do
      indexa_identidade()
      uri = "at://did:plc:alice/place.quintal.feed.prosa/abc"

      {:ok, _} =
        Prosas.indexar(session.did, %{
          uri: uri,
          cid: "bafy",
          value: %{text: "vai embora", created_at: "2026-08-01T10:00:00Z"}
        })

      expect(PDSMock, :delete_record, fn _session, "place.quintal.feed.prosa", "abc", _opts ->
        :ok
      end)

      assert :ok = Prosas.apagar(session, uri)
      assert Repo.get(Prosa, uri) == nil
    end

    test "prosa alheia não sai de casa", %{session: session} do
      indexa_identidade("did:plc:beto")
      uri = "at://did:plc:beto/place.quintal.feed.prosa/xyz"

      {:ok, _} =
        Prosas.indexar("did:plc:beto", %{
          uri: uri,
          cid: "bafy",
          value: %{text: "prosa do beto", created_at: "2026-08-01T10:00:00Z"}
        })

      assert {:error, :prosa_alheia} = Prosas.apagar(session, uri)
      assert Repo.get(Prosa, uri)
    end

    test "erro do pds propaga e o índice fica intacto", %{session: session} do
      indexa_identidade()
      uri = "at://did:plc:alice/place.quintal.feed.prosa/abc"

      {:ok, _} =
        Prosas.indexar(session.did, %{
          uri: uri,
          cid: "bafy",
          value: %{text: "fica", created_at: "2026-08-01T10:00:00Z"}
        })

      stub(PDSMock, :delete_record, fn _session, _collection, _rkey, _opts ->
        {:error, :pds_fora_do_ar}
      end)

      assert {:error, :pds_fora_do_ar} = Prosas.apagar(session, uri)
      assert Repo.get(Prosa, uri)
    end
  end

  describe "list_por_autor/2" do
    test "cronológica, da mais nova para a mais antiga", %{session: session} do
      indexa_identidade()

      for {texto, dia} <- [{"antiga", "2026-08-01"}, {"nova", "2026-08-03"}, {"meio", "2026-08-02"}] do
        {:ok, _} =
          Prosas.indexar(session.did, %{
            uri: "at://did:plc:alice/place.quintal.feed.prosa/#{texto}",
            cid: "bafy",
            value: %{text: texto, created_at: "#{dia}T10:00:00Z"}
          })
      end

      assert ["nova", "meio", "antiga"] ==
               session.did |> Prosas.list_por_autor() |> Enum.map(& &1.texto)
    end

    test "só as prosas da pessoa", %{session: session} do
      indexa_identidade()
      indexa_identidade("did:plc:beto")

      {:ok, _} =
        Prosas.indexar("did:plc:beto", %{
          uri: "at://did:plc:beto/place.quintal.feed.prosa/xyz",
          cid: "bafy",
          value: %{text: "prosa do beto", created_at: "2026-08-01T10:00:00Z"}
        })

      assert Prosas.list_por_autor(session.did) == []
    end
  end

  describe "indexar/2" do
    test "upsert idempotente: o eco do firehose é o mesmo evento" do
      indexa_identidade()

      record = %{
        uri: "at://did:plc:alice/place.quintal.feed.prosa/abc",
        cid: "bafy1",
        value: %{"text" => "original", "createdAt" => "2026-08-01T10:00:00Z"}
      }

      assert {:ok, _} = Prosas.indexar("did:plc:alice", record)
      assert {:ok, _} = Prosas.indexar("did:plc:alice", %{record | cid: "bafy2"})

      assert Repo.aggregate(Prosa, :count) == 1
      assert Repo.get!(Prosa, record.uri).cid == "bafy2"
    end

    test "resposta indexa root e parent do reply" do
      indexa_identidade()

      value = %{
        text: "concordo",
        created_at: "2026-08-01T10:00:00Z",
        reply: %{
          root: %{uri: "at://did:plc:alice/place.quintal.feed.prosa/raiz", cid: "c1"},
          parent: %{uri: "at://did:plc:alice/place.quintal.feed.prosa/mae", cid: "c2"}
        }
      }

      assert {:ok, prosa} =
               Prosas.indexar("did:plc:alice", %{
                 uri: "at://did:plc:alice/place.quintal.feed.prosa/resp",
                 cid: "bafy",
                 value: value
               })

      assert prosa.reply_root == "at://did:plc:alice/place.quintal.feed.prosa/raiz"
      assert prosa.reply_parent == "at://did:plc:alice/place.quintal.feed.prosa/mae"
    end

    test "imagens viram linhas ordenadas, com alt, e o reindex troca o conjunto" do
      indexa_identidade()
      uri = "at://did:plc:alice/place.quintal.feed.prosa/fotos"
      blob = %{"$type" => "blob", "ref" => %{"$link" => "bafkblob"}, "mimeType" => "image/png", "size" => 42}

      value = %{
        "text" => "olha o quintal",
        "createdAt" => "2026-08-01T10:00:00Z",
        "images" => [%{"image" => blob, "alt" => "um quintal de manhã"}]
      }

      assert {:ok, prosa} = Prosas.indexar("did:plc:alice", %{uri: uri, cid: "bafy", value: value})

      assert [%{alt: "um quintal de manhã", posicao: 0, blob: %{"ref" => %{"$link" => "bafkblob"}}}] =
               prosa.imagens

      assert {:ok, prosa} =
               Prosas.indexar("did:plc:alice", %{
                 uri: uri,
                 cid: "bafy2",
                 value: Map.delete(value, "images")
               })

      assert prosa.imagens == []
      assert Repo.aggregate(Quintal.ProsaImagem, :count) == 0
    end
  end

  describe "responder/3" do
    test "escreve o record com reply apontando pra raiz e pra mãe", %{session: session} do
      indexa_identidade()
      mae_uri = "at://did:plc:alice/place.quintal.feed.prosa/mae"

      {:ok, mae} =
        Prosas.indexar(session.did, %{
          uri: mae_uri,
          cid: "bafy-mae",
          value: %{text: "prosa mãe", created_at: "2026-08-01T10:00:00Z"}
        })

      expect(PDSMock, :create_record, fn _session, "place.quintal.feed.prosa", record ->
        assert record["reply"] == %{
                 "root" => %{"uri" => mae_uri, "cid" => "bafy-mae"},
                 "parent" => %{"uri" => mae_uri, "cid" => "bafy-mae"}
               }

        {:ok, %{uri: "at://did:plc:alice/place.quintal.feed.prosa/resp", cid: "bafy-resp"}}
      end)

      assert {:ok, resposta} = Prosas.responder(session, mae, "concordo demais")
      assert resposta.reply_root == mae_uri
      assert resposta.reply_parent == mae_uri
    end

    test "resposta a resposta ancora na raiz da thread", %{session: session} do
      indexa_identidade()

      {:ok, raiz} =
        Prosas.indexar(session.did, %{
          uri: "at://did:plc:alice/place.quintal.feed.prosa/raiz",
          cid: "bafy-raiz",
          value: %{text: "raiz", created_at: "2026-08-01T10:00:00Z"}
        })

      {:ok, mae} =
        Prosas.indexar(session.did, %{
          uri: "at://did:plc:alice/place.quintal.feed.prosa/mae",
          cid: "bafy-mae",
          value: %{
            text: "meio",
            created_at: "2026-08-01T11:00:00Z",
            reply: %{
              root: %{uri: raiz.uri, cid: raiz.cid},
              parent: %{uri: raiz.uri, cid: raiz.cid}
            }
          }
        })

      expect(PDSMock, :create_record, fn _session, _collection, record ->
        assert record["reply"]["root"]["uri"] == raiz.uri
        assert record["reply"]["parent"]["uri"] == mae.uri
        {:ok, %{uri: "at://did:plc:alice/place.quintal.feed.prosa/neta", cid: "bafy-neta"}}
      end)

      assert {:ok, neta} = Prosas.responder(session, mae, "fundindo a thread")
      assert neta.reply_root == raiz.uri
    end

    test "mãe fora do índice falha em casa", %{session: session} do
      mae = %Prosa{uri: "at://did:plc:sumiu/place.quintal.feed.prosa/x", cid: "c"}

      assert {:error, :mae_fora_do_indice} = Prosas.responder(session, mae, "alô?")
    end
  end

  describe "respostas/2 e pais/1" do
    test "thread cronológica e handle da mãe", %{session: session} do
      indexa_identidade()
      indexa_identidade("did:plc:beto")
      mae_uri = "at://did:plc:alice/place.quintal.feed.prosa/mae"

      {:ok, _} =
        Prosas.indexar(session.did, %{
          uri: mae_uri,
          cid: "bafy",
          value: %{text: "mãe", created_at: "2026-08-01T10:00:00Z"}
        })

      for {texto, hora} <- [{"segunda", "12"}, {"primeira", "11"}] do
        {:ok, _} =
          Prosas.indexar("did:plc:beto", %{
            uri: "at://did:plc:beto/place.quintal.feed.prosa/#{texto}",
            cid: "bafy",
            value: %{
              text: texto,
              created_at: "2026-08-01T#{hora}:00:00Z",
              reply: %{
                root: %{uri: mae_uri, cid: "bafy"},
                parent: %{uri: mae_uri, cid: "bafy"}
              }
            }
          })
      end

      assert ["primeira", "segunda"] == mae_uri |> Prosas.respostas() |> Enum.map(& &1.texto)

      resp_uri = "at://did:plc:beto/place.quintal.feed.prosa/primeira"
      assert Prosas.pais([mae_uri]) == %{mae_uri => "did:plc:alice"}
      assert Prosas.pais([resp_uri]) == %{resp_uri => "did:plc:beto"}
      assert Prosas.pais(["at://did:plc:ninguem/place.quintal.feed.prosa/x"]) == %{}
    end
  end
end
