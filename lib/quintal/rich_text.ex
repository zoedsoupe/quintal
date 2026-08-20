defmodule Quintal.RichText do
  @moduledoc """
  Deriva facets atproto da fonte markdown de uma prosa (core puro,
  espec 10.1 + `place.quintal.richtext.facet`).

  O `text` do record guarda a fonte markdown (legível em qualquer
  client); os facets são metadado derivado, nunca escritos à mão:
  ênfase vira features `place.quintal.richtext.facet#*`, links e
  menções viram `app.bsky.richtext.facet#link|#mention`, que todo
  client atproto já entende.

  Os ranges são byte offsets UTF-8 (0-based, fim exclusivo) sobre o
  conteúdo interno do nó — os markers (`**`, crases) ficam de fora.
  O sourcepos do comrak é 1-based em bytes com fim inclusivo, daí o
  `- 1` no começo e nada no fim.

  A resolução de handle é a única parte com efeito colateral e entra
  injetada (`:resolver`), default `ProtoRune.Atproto.Identity`.
  """

  alias MDEx.Sourcepos
  alias ProtoRune.Atproto

  @facet "place.quintal.richtext.facet"
  @bsky_facet "app.bsky.richtext.facet"

  @mdex_opts [extension: [strikethrough: true, autolink: true]]

  @mention ~r/@[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}/

  @doc """
  Os facets de uma fonte markdown, em wire format (chaves string,
  `byteStart`/`byteEnd`), ordenados por começo. Texto sem nada
  marcado devolve `[]`.

  Opções: `:resolver` (`handle :: String.t() -> {:ok, did} | {:error, _}`),
  usada nas menções; falha de resolução deixa o `@handle` como texto
  puro, sem facet.
  """
  @spec facets(texto :: String.t(), opts :: keyword()) :: [map()]
  def facets(texto, opts \\ []) when is_binary(texto) do
    resolver = Keyword.get(opts, :resolver, &Atproto.Identity.resolve_handle/1)
    doc = MDEx.parse_document!(texto, @mdex_opts)
    offsets = line_offsets(texto)

    Enum.sort_by(
      estilo_facets(doc.nodes, offsets) ++ mention_facets(doc.nodes, offsets, resolver),
      & &1["index"]["byteStart"]
    )
  end

  # Ênfase, código e links: o facet cobre o miolo (do começo do
  # primeiro filho ao fim do último), nunca os markers. Facets de
  # nós aninhados (itálico dentro de negrito) se sobrepõem — clients
  # que não entendem a sobreposição ignoram a feature desconhecida.
  defp estilo_facets(nodes, offsets) do
    nodes
    |> Enum.flat_map(fn
      %MDEx.Strong{} = node ->
        [facet(node, offsets, %{"$type" => "#{@facet}#bold"}) | estilo_facets(node.nodes, offsets)]

      %MDEx.Emph{} = node ->
        [facet(node, offsets, %{"$type" => "#{@facet}#italic"}) | estilo_facets(node.nodes, offsets)]

      %MDEx.Strikethrough{} = node ->
        [facet(node, offsets, %{"$type" => "#{@facet}#strike"}) | estilo_facets(node.nodes, offsets)]

      %MDEx.Code{} = node ->
        [code_facet(node, offsets)]

      %MDEx.Link{url: url} = node ->
        [facet(node, offsets, %{"$type" => "#{@bsky_facet}#link", "uri" => url}) | estilo_facets(node.nodes, offsets)]

      node ->
        estilo_facets(filhos(node), offsets)
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Resolver é rede (plc/did:web): cap de 20 menções por prosa e
  # resolução concorrente com timeout, pra uma prosa cheia de @handles
  # não segurar o publicar em centenas de chamadas sequenciais.
  @max_mencoes 20

  defp mention_facets(nodes, offsets, resolver) do
    nodes
    |> textos_fora_de_link()
    |> Enum.flat_map(fn %MDEx.Text{literal: literal, sourcepos: sourcepos} ->
      base = byte_start(sourcepos, offsets)

      @mention
      |> Regex.scan(literal, return: :index)
      |> Enum.map(fn [{index, len}] -> {base + index, base + index + len, binary_part(literal, index, len)} end)
    end)
    |> Enum.uniq_by(fn {_s, _e, handle} -> handle end)
    |> Enum.take(@max_mencoes)
    |> Task.async_stream(
      fn {s, e, handle} ->
        case resolver.(String.trim_leading(handle, "@")) do
          {:ok, did} -> [facet_map(s, e, %{"$type" => "#{@bsky_facet}#mention", "did" => did})]
          {:error, _sem_resolve} -> []
        end
      end,
      max_concurrency: 8,
      timeout: 2_000,
      on_timeout: :kill_task
    )
    |> Enum.flat_map(fn
      {:ok, facets} -> facets
      _timeout_ou_queda -> []
    end)
  end

  defp textos_fora_de_link(nodes) do
    Enum.flat_map(nodes, fn
      %MDEx.Link{} -> []
      %MDEx.Text{} = text -> [text]
      node -> textos_fora_de_link(filhos(node))
    end)
  end

  # Range do miolo: começo do primeiro filho ao fim do último
  defp miolo_range(%{nodes: [primeiro | _] = filhos}, offsets) do
    {byte_start(primeiro.sourcepos, offsets), byte_end(List.last(filhos).sourcepos, offsets)}
  end

  defp miolo_range(%{nodes: []}, _offsets), do: nil

  defp facet(node, offsets, feature) do
    case miolo_range(node, offsets) do
      {s, e} -> facet_map(s, e, feature)
      nil -> nil
    end
  end

  defp code_facet(%MDEx.Code{sourcepos: sourcepos, num_backticks: n}, offsets) do
    facet_map(
      byte_start(sourcepos, offsets) + n,
      byte_end(sourcepos, offsets) - n,
      %{"$type" => "#{@facet}#code"}
    )
  end

  defp facet_map(s, e, feature) do
    %{"index" => %{"byteStart" => s, "byteEnd" => e}, "features" => [feature]}
  end

  defp filhos(node) when is_map(node), do: Map.get(node, :nodes) || []

  defp byte_start(%Sourcepos{start: {line, col}}, offsets), do: offsets[line] + col - 1
  defp byte_end(%Sourcepos{end: {line, col}}, offsets), do: offsets[line] + col

  # mapa linha (1-based) => byte offset do começo da linha no texto
  defp line_offsets(texto) do
    {_pos, offsets} =
      texto
      |> String.split("\n")
      |> Enum.with_index(1)
      |> Enum.reduce({0, %{}}, fn {line, i}, {pos, acc} ->
        {pos + byte_size(line) + 1, Map.put(acc, i, pos)}
      end)

    offsets
  end
end
