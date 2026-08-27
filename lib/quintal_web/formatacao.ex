defmodule QuintalWeb.Formatacao do
  @moduledoc """
  Formatação compartilhada das telas: tempo relativo em sussurro, trecho
  de prosa longa e imagens do card. Vive fora das LiveViews porque home,
  canto e visitas falam a mesma língua.
  """

  @doc """
  Tempo relativo em sussurro (briefing 4.2): "há 2h", não carimbo.
  """
  def tempo_relativo(%DateTime{} = data) do
    case DateTime.diff(DateTime.utc_now(), data, :second) do
      s when s < 60 -> "agora"
      s when s < 3_600 -> "há #{div(s, 60)}min"
      s when s < 86_400 -> "há #{div(s, 3_600)}h"
      s when s < 172_800 -> "ontem"
      s when s < 604_800 -> "há #{div(s, 86_400)}d"
      _ -> Calendar.strftime(data, "%d/%m/%Y")
    end
  end

  def tempo_relativo(_outra), do: ""

  @doc """
  Data curta para o índice de prosas do canto: "12/03" no ano corrente,
  "12/03/25" quando o ano já virou.
  """
  def data_curta(%DateTime{} = data) do
    if data.year == DateTime.utc_now().year do
      Calendar.strftime(data, "%d/%m")
    else
      Calendar.strftime(data, "%d/%m/%y")
    end
  end

  def data_curta(_outra), do: ""

  @frase 90

  @doc """
  A primeira frase de uma prosa, para a linha do índice do canto: corta
  no fim da frase ou da primeira linha, o que vier antes, e no máximo
  em #{@frase} caracteres (no espaço mais perto do limite). Devolve
  fonte markdown — quem renderiza é o `Markdown.render_inline/1`, que
  completa um marker aberto pelo corte.
  """
  def primeira_frase(texto) when is_binary(texto) do
    frase =
      texto
      |> String.trim()
      |> String.split(~r/(?<=[.!?…])\s+|\n/u, parts: 2)
      |> hd()

    if String.length(frase) > @frase do
      corte = frase |> String.slice(0, @frase) |> String.replace(~r/\s+\S*$/u, "")
      corte <> "…"
    else
      frase
    end
  end

  @resumo 350

  @doc """
  Trecho de prosa longa para o feed e o canto: crônicas e ensaios abrem
  em página própria, na lista entra só o começo. Corta no espaço mais
  perto do limite e devolve `{texto, cortou?}` — fonte markdown, que o
  card renderiza (o modo streaming do comrak completa marker aberto
  pelo corte).
  """
  def trecho(texto) when is_binary(texto) do
    if String.length(texto) <= @resumo do
      {texto, false}
    else
      corte =
        texto
        |> String.slice(0, @resumo)
        |> String.replace(~r/\s+\S*$/u, "")

      {corte <> "…", true}
    end
  end

  @doc "O caminho da página de leitura de uma prosa."
  def prosa_path(uri, handle) do
    rkey = uri |> String.split("/") |> List.last()
    "/canto/#{handle}/prosa/#{rkey}"
  end

  @doc """
  As imagens de uma prosa prontas para o card: `%{src, alt}`.

  A url aponta direto para o `getBlob` do pds do autor (o `pds_url` vem
  da identidade indexada). ponytail: sem proxy próprio no alpha; o proxy
  com cache do spec 9.6 entra quando a leitura de blobs pesar.
  """
  def imagens_card(%{imagens: imagens} = prosa) do
    pds_url = if Ecto.assoc_loaded?(prosa.autor) && prosa.autor, do: prosa.autor.pds_url

    if pds_url && is_list(imagens) do
      Enum.map(imagens, &%{src: blob_url(pds_url, prosa.autor_did, &1.blob), alt: &1.alt})
    else
      []
    end
  end

  @doc "A url de leitura de um blob: `getBlob` direto no pds do autor."
  def blob_url(pds_url, did, blob) do
    cid = get_in(blob, ["ref", "$link"]) || get_in(blob, [:ref, :"$link"])

    "#{pds_url}/xrpc/com.atproto.sync.getBlob?did=#{URI.encode_www_form(did)}&cid=#{URI.encode_www_form(to_string(cid))}"
  end

  @doc "A url do avatar de uma identidade, `nil` quando não há foto ou pds."
  def avatar_url(%{pds_url: pds_url, did: did}, blob) when is_binary(pds_url) and is_map(blob) do
    blob_url(pds_url, did, blob)
  end

  def avatar_url(_identidade, _blob), do: nil
end
