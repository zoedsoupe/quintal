defmodule Quintal.RichTextTest do
  use ExUnit.Case, async: true

  alias Quintal.RichText

  defp resolver_ok(handle), do: {:ok, "did:plc:fake-#{handle}"}
  defp resolver_erro(_handle), do: {:error, :nxdomain}

  defp facet(facets, type) do
    Enum.find(facets, fn %{"features" => [feature | _]} -> feature["$type"] == type end)
  end

  defp range(facet), do: {facet["index"]["byteStart"], facet["index"]["byteEnd"]}

  test "texto sem marcação não tem facets" do
    assert RichText.facets("bom dia, quintal") == []
  end

  test "ênfase cobre o miolo, nunca os markers" do
    texto = "**bold** e *it* ~~ris~~ `c`"
    facets = RichText.facets(texto)

    assert range(facet(facets, "place.quintal.richtext.facet#bold")) == {2, 6}
    assert range(facet(facets, "place.quintal.richtext.facet#italic")) == {12, 14}
    assert range(facet(facets, "place.quintal.richtext.facet#strike")) == {18, 21}
    assert range(facet(facets, "place.quintal.richtext.facet#code")) == {25, 26}
  end

  test "byte ranges são UTF-8: acento e emoji antes não deslocam" do
    texto = "éé **bó** 👋"
    facets = RichText.facets(texto)

    # "éé " são 5 bytes, "**" mais 2: bó começa no 7 e tem 3 bytes
    assert range(facet(facets, "place.quintal.richtext.facet#bold")) == {7, 10}
  end

  test "range multilinha atravessa quebras de linha" do
    texto = "linha 1\n\n**bold\nmultilinha**"
    facets = RichText.facets(texto)

    {s, e} = range(facet(facets, "place.quintal.richtext.facet#bold"))
    assert String.slice(texto, 0, s) =~ ~r/\*\*$/
    assert binary_part(texto, s, e - s) == "bold\nmultilinha"
  end

  test "link markdown vira facet bsky com a url" do
    facets = RichText.facets("lê [esse texto](https://exemplo.co) depois")
    link = facet(facets, "app.bsky.richtext.facet#link")

    assert link["features"] |> hd() |> Map.get("uri") == "https://exemplo.co"
    # "lê " são 4 bytes: o miolo do link começa no 5
    assert range(link) == {5, 15}
  end

  test "url crua vira link pelo autolink" do
    facets = RichText.facets("olha https://exemplo.co aí")
    assert facet(facets, "app.bsky.richtext.facet#link")
  end

  test "menção resolve o handle e vira facet bsky" do
    facets = RichText.facets("oi @alice.bsky.social", resolver: &resolver_ok/1)
    mention = facet(facets, "app.bsky.richtext.facet#mention")

    assert mention["features"] |> hd() |> Map.get("did") == "did:plc:fake-alice.bsky.social"
    assert range(mention) == {3, 21}
  end

  test "menção com acento antes mantém o byte offset" do
    facets = RichText.facets("é @alice.bsky.social", resolver: &resolver_ok/1)
    mention = facet(facets, "app.bsky.richtext.facet#mention")

    # "é " são 3 bytes: a menção começa no 3
    assert range(mention) == {3, 21}
  end

  test "handle que não resolve fica como texto puro" do
    assert RichText.facets("oi @fantasma.bsky.social", resolver: &resolver_erro/1) == []
  end

  test "menção dentro de link ou código não vira facet" do
    texto = "[m @no.co](https://z.co) e `x@y.com`"
    assert texto |> RichText.facets(resolver: &resolver_ok/1) |> facet("app.bsky.richtext.facet#mention") == nil
  end

  test "facets saem ordenados por byteStart" do
    facets = RichText.facets("`a` **b** *c*", resolver: &resolver_ok/1)
    starts = Enum.map(facets, & &1["index"]["byteStart"])

    assert starts == Enum.sort(starts)
  end
end
