defmodule Quintal.LexiconTest do
  use ExUnit.Case, async: true

  alias Quintal.Lexicon

  @prosa %{
    "text" => "bom dia, quintal",
    "tipo" => "nota",
    "createdAt" => "2026-08-18T12:00:00.000Z"
  }

  describe "place.quintal.feed.prosa" do
    test "prosa válida passa" do
      assert :ok = Lexicon.validate("place.quintal.feed.prosa", @prosa)
    end

    test "prosa completa, com reply e imagens, passa" do
      completa =
        Map.merge(@prosa, %{
          "reply" => %{
            "root" => %{"uri" => "at://did:plc:a/place.quintal.feed.prosa/1", "cid" => "bafy1"},
            "parent" => %{"uri" => "at://did:plc:a/place.quintal.feed.prosa/2", "cid" => "bafy2"}
          },
          "images" => [%{"image" => %{"ref" => %{"$link" => "bafy"}}, "alt" => "um axolote"}],
          "langs" => ["pt-BR"]
        })

      assert :ok = Lexicon.validate("place.quintal.feed.prosa", completa)
    end

    test "falta de campo obrigatório acusa" do
      assert {:error, errors} = Lexicon.validate("place.quintal.feed.prosa", %{"tipo" => "nota"})
      assert "$: missing required field \"text\"" in errors
      assert "$: missing required field \"createdAt\"" in errors
    end

    test "campo desconhecido acusa" do
      prosa = Map.put(@prosa, "likes", 42)
      assert {:error, errors} = Lexicon.validate("place.quintal.feed.prosa", prosa)
      assert "$: unknown field \"likes\"" in errors
    end

    test "tipo fora dos knownValues acusa" do
      prosa = Map.put(@prosa, "tipo", "desabafo")
      assert {:error, errors} = Lexicon.validate("place.quintal.feed.prosa", prosa)
      assert Enum.any?(errors, &String.contains?(&1, "not in"))
    end

    test "createdAt malformado acusa" do
      prosa = Map.put(@prosa, "createdAt", "ontem")
      assert {:error, errors} = Lexicon.validate("place.quintal.feed.prosa", prosa)
      assert "$.createdAt: expected ISO 8601 datetime" in errors
    end

    test "mais de 4 imagens acusa" do
      imagem = %{"image" => %{"ref" => %{"$link" => "bafy"}}, "alt" => "x"}
      prosa = Map.put(@prosa, "images", List.duplicate(imagem, 5))
      assert {:error, errors} = Lexicon.validate("place.quintal.feed.prosa", prosa)
      assert "$.images: at most 4 items, got 5" in errors
    end

    test "texto acima de 10.000 grafemes acusa" do
      prosa = Map.put(@prosa, "text", String.duplicate("a", 10_001))
      assert {:error, errors} = Lexicon.validate("place.quintal.feed.prosa", prosa)
      assert "$.text: at most 10000 graphemes, got 10001" in errors
    end

    test "facets bsky e quintal passam na union" do
      facets = [
        %{
          "index" => %{"byteStart" => 2, "byteEnd" => 6},
          "features" => [%{"$type" => "place.quintal.richtext.facet#bold"}]
        },
        %{
          "index" => %{"byteStart" => 10, "byteEnd" => 15},
          "features" => [%{"$type" => "app.bsky.richtext.facet#link", "uri" => "https://exemplo.co"}]
        }
      ]

      prosa = Map.put(@prosa, "facets", facets)
      assert :ok = Lexicon.validate("place.quintal.feed.prosa", prosa)
    end

    test "facet que não é objeto acusa" do
      prosa = Map.put(@prosa, "facets", ["bold"])
      assert {:error, errors} = Lexicon.validate("place.quintal.feed.prosa", prosa)
      assert Enum.any?(errors, &String.contains?(&1, "union"))
    end
  end

  describe "place.quintal.canto.recado" do
    @recado %{
      "subject" => "did:plc:vizinha",
      "text" => "passando pra deixar um abraço",
      "createdAt" => "2026-08-18T12:00:00.000Z"
    }

    test "recado válido passa" do
      assert :ok = Lexicon.validate("place.quintal.canto.recado", @recado)
    end

    test "subject que não é did acusa" do
      recado = Map.put(@recado, "subject", "alice.bsky.social")
      assert {:error, errors} = Lexicon.validate("place.quintal.canto.recado", recado)
      assert "$.subject: expected did" in errors
    end

    test "recado acima de 500 grafemes acusa" do
      recado = Map.put(@recado, "text", String.duplicate("a", 501))
      assert {:error, _} = Lexicon.validate("place.quintal.canto.recado", recado)
    end
  end

  describe "place.quintal.canto.config" do
    test "config válida passa" do
      config = %{
        "tema" => "gloss",
        "blocos" => ["bio", "prosas"],
        "links" => [%{"titulo" => "blog antigo", "url" => "https://exemplo.com"}],
        "updatedAt" => "2026-08-18T12:00:00.000Z"
      }

      assert :ok = Lexicon.validate("place.quintal.canto.config", config)
    end

    test "bloco fora dos knownValues acusa" do
      config = %{"tema" => "papel", "blocos" => ["mural"], "updatedAt" => "2026-08-18T12:00:00Z"}

      assert {:error, errors} = Lexicon.validate("place.quintal.canto.config", config)
      assert Enum.any?(errors, &String.contains?(&1, "blocos[0]"))
    end

    test "mais de 8 links acusa" do
      link = %{"titulo" => "x", "url" => "https://exemplo.com"}

      config = %{
        "tema" => "papel",
        "blocos" => [],
        "links" => List.duplicate(link, 9),
        "updatedAt" => "2026-08-18T12:00:00Z"
      }

      assert {:error, errors} = Lexicon.validate("place.quintal.canto.config", config)
      assert "$.links: at most 8 items, got 9" in errors
    end
  end

  test "coleção sem lexicon local é erro" do
    assert {:error, ["unknown lexicon: app.bsky.feed.post"]} =
             Lexicon.validate("app.bsky.feed.post", %{})
  end
end
