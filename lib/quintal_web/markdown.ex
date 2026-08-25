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
      |> ajusta_links()

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

  defp linkify_trecho(texto) do
    Regex.replace(@mention, texto, fn handle ->
      linkified_handle = String.trim_leading(handle, "@")
      ~s(<a href="/canto/#{linkified_handle}">#{handle}</a>)
    end)
  end
end
