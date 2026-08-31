defmodule QuintalWeb.Markdown do
  @moduledoc """
  Render server-side da fonte markdown das prosas (e recados, bios e
  depoimentos): MDEx/comrak com strikethrough e autolink GFM, HTML cru
  escapado pelo próprio comrak: markdown da pessoa vira HTML seguro
  sem sanitize extra.
  """

  @mention ~r/@[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}/

  @doc """
  HTML seguro (`{:safe, html}`) da fonte markdown.

  Modo streaming do comrak: um trecho cortado no meio de um marker
  (`**bo…` no resumo do feed) renderiza com a construção completada,
  nunca com asteriscos literais vazando.
  """
  @spec render(texto :: String.t() | nil) :: {:safe, String.t()}
  def render(texto) when is_binary(texto) do
    html =
      [streaming: true, extension: [strikethrough: true, autolink: true]]
      |> MDEx.new()
      |> MDEx.Document.put_markdown(texto)
      |> MDEx.to_html!()
      |> limpa_incompletos()
      |> ajusta_links()
      |> embeds()

    {:safe, html}
  end

  def render(_sem_texto), do: {:safe, ""}

  @doc """
  Render inline, sem o `<p>` de bloco: a frase do índice do canto é
  uma linha só, e nela o markdown vale para ênfase e links, não para
  estrutura. Âncoras viram texto puro: a linha do índice já é um link
  (a prosa inteira), e `<a>` dentro de `<a>` quebra o HTML.
  """
  @spec render_inline(texto :: String.t() | nil) :: {:safe, String.t()}
  def render_inline(texto) when is_binary(texto) do
    {:safe, html} = render(texto)

    html =
      html
      |> String.replace(~r/^<p>(.*)<\/p>\n?$/s, "\\1")
      |> String.replace(~r/<\/?a\b[^>]*>/, "")

    {:safe, html}
  end

  def render_inline(sem_texto), do: render(sem_texto)

  # Ajustes no HTML pronto, não na árvore: traverse_and_update é
  # pós-ordem e troca um nó por um nó, então não sabe que está dentro
  # de <a>/<code> nem quebra "oi @fulano.com" em [texto, link, texto];
  # e os attrs de MDEx.Link nem chegam ao HTML, quem renderiza é o
  # comrak. O split em tags faz a menção nunca tocar atributo (o
  # `mailto:` de um email autolinkado, por exemplo); dentro de <a> e
  # <code> ela fica quieta. O charset do handle (letra, dígito, ponto,
  # traço) não quebra HTML.
  @tag ~r/<[^>]+>/

  # Resumo cortado no meio de uma referência (`![foto]`, `[texto]` no
  # fim do trecho) vira `mdex:incomplete-link` no src/href: a imagem
  # quebrada dispara a CSP e o link não leva a lugar nenhum. A imagem
  # vira o próprio alt e a âncora vira texto puro.
  defp limpa_incompletos(html) do
    html
    |> String.replace(~r/<img src="mdex:incomplete-link" alt="([^"]*)" \/>/, "\\1")
    |> String.replace(~r/<a href="mdex:incomplete-link">(.*?)<\/a>/s, "\\1")
  end

  defp ajusta_links(html) do
    {partes, _estado} =
      @tag
      |> Regex.split(html, include_captures: true)
      |> Enum.map_reduce({0, 0}, fn
        "<a " <> _ = tag, {a, c} -> {alvo_externo(tag), {a + 1, c}}
        "</a>" = tag, {a, c} -> {tag, {a - 1, c}}
        "<code" <> _ = tag, {a, c} -> {tag, {a, c + 1}}
        "</code>" = tag, {a, c} -> {tag, {a, c - 1}}
        "<" <> _ = tag, estado -> {tag, estado}
        texto, {0, 0} -> {linkify_trecho(texto), {0, 0}}
        texto, estado -> {texto, estado}
      end)

    Enum.join(partes)
  end

  # Link externo abre em aba nova; interno (/canto/...) e mailto ficam.
  defp alvo_externo(~s(<a href="http) <> _ = tag) do
    String.replace(tag, "<a ", ~s(<a target="_blank" rel="noopener" ), global: false)
  end

  defp alvo_externo(tag), do: tag

  # Embeds derivados da URL (youtube, apple music, spotify): um
  # parágrafo que é só o link vira player em iframe, com o link original
  # embaixo como fallback. O embed é apresentação, nunca dado do record:
  # outro client vê o link, que já basta. Youtube é vídeo e música:
  # shorts não vira embed (nem chega aqui, o composer tira do texto).
  @link_sozinho ~r/<p><a\s[^>]*href="(https?:\/\/[^"]+)"[^>]*>[^<]*<\/a><\/p>/

  defp embeds(html) do
    Regex.replace(@link_sozinho, html, fn original, url ->
      case embed_player(url) do
        nil ->
          original

        {classe, src, titulo, attrs} ->
          ~s(<figure class="embed #{classe}">) <>
            ~s(<iframe src="#{src}" title="#{titulo}" loading="lazy" #{attrs}></iframe>) <>
            ~s(<figcaption><a href="#{url}" target="_blank" rel="noopener">#{url}</a></figcaption></figure>)
      end
    end)
  end

  defp embed_player(url) do
    uri = URI.parse(url)

    cond do
      id = youtube_id(uri) ->
        {"embed--video", "https://www.youtube-nocookie.com/embed/#{id}", "vídeo do youtube",
         ~s(sandbox="allow-scripts allow-same-origin allow-presentation allow-popups" allowfullscreen)}

      uri.host == "music.apple.com" && uri.path ->
        query = if uri.query, do: "?#{uri.query}"

        {"embed--musica", "https://embed.music.apple.com#{uri.path}#{query}", "apple music",
         ~s(sandbox="allow-forms allow-popups allow-same-origin allow-scripts allow-top-navigation-by-user-activation")}

      src = spotify_embed(uri) ->
        {"embed--musica", src, "spotify",
         ~s(sandbox="allow-scripts allow-same-origin allow-popups allow-encrypted-media")}

      true ->
        nil
    end
  end

  @youtube_id ~r/^[\w-]{11}$/

  defp youtube_id(%URI{host: host} = uri) when host in ~w(youtube.com www.youtube.com m.youtube.com music.youtube.com) do
    if uri.path == "/watch" do
      uri.query |> URI.decode_query() |> Map.get("v") |> valida_youtube_id()
    end
  end

  defp youtube_id(%URI{host: "youtu.be", path: "/" <> id}), do: valida_youtube_id(id)
  defp youtube_id(_uri), do: nil

  defp valida_youtube_id(id) when is_binary(id) do
    if Regex.match?(@youtube_id, id), do: id
  end

  defp valida_youtube_id(_sem_id), do: nil

  # open.spotify.com/track|album|playlist|episode|show/<id>, com ou sem
  # /intl-xx no caminho: o embed é o mesmo path sob /embed
  @spotify_tipos ~w(track album playlist episode show)

  defp spotify_embed(%URI{host: "open.spotify.com", path: path}) when is_binary(path) do
    partes = String.split(path, "/", trim: true)

    case Enum.find_index(partes, &(&1 in @spotify_tipos)) do
      nil ->
        nil

      i ->
        with tipo when is_binary(tipo) <- Enum.at(partes, i),
             id when is_binary(id) <- Enum.at(partes, i + 1),
             true <- Regex.match?(~r/^\w{22}$/, id) do
          "https://open.spotify.com/embed/#{tipo}/#{id}"
        else
          _forma_estranha -> nil
        end
    end
  end

  defp spotify_embed(_uri), do: nil

  defp linkify_trecho(texto) do
    Regex.replace(@mention, texto, fn handle ->
      linkified_handle = String.trim_leading(handle, "@")
      ~s(<a href="/canto/#{linkified_handle}">#{handle}</a>)
    end)
  end
end
