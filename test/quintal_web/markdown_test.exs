defmodule QuintalWeb.MarkdownTest do
  use ExUnit.Case, async: true

  alias QuintalWeb.Markdown

  defp html(texto), do: texto |> Markdown.render() |> elem(1)

  describe "render/1" do
    test "ênfase vira tag html" do
      saida = html("**bold** *it* ~~ris~~ `c`")

      assert saida =~ "<strong>bold</strong>"
      assert saida =~ "<em>it</em>"
      assert saida =~ "<del>ris</del>"
      assert saida =~ "<code>c</code>"
    end

    test "blocos: título, lista e citação" do
      saida = html("## tit\n\n- a\n- b\n\n> quote")

      assert saida =~ "<h2>tit</h2>"
      assert saida =~ "<li>a</li>"
      assert saida =~ "<blockquote>"
    end

    test "html cru não executa: o comrak escapa" do
      refute html("<script>alert(1)</script>") =~ "<script>"
    end

    test "nil e vazio renderizam vazio seguro" do
      assert Markdown.render(nil) == {:safe, ""}
    end

    test "marker aberto pelo corte do trecho é completado (streaming)" do
      assert html("**bold sem fechar") =~ "<strong>bold sem fechar</strong>"
    end
  end

  describe "render_inline/1" do
    test "tira o <p> de bloco mas mantém ênfase e links" do
      {:safe, saida} = Markdown.render_inline("**bold** e @alice.bsky.social")

      refute saida =~ "<p>"
      assert saida =~ "<strong>bold</strong>"
      # assert saida =~ "bsky.app/profile/alice.bsky.social"
    end
  end

  describe "embeds" do
    test "link do youtube sozinho no parágrafo vira player" do
      saida = html("olha isso\n\nhttps://www.youtube.com/watch?v=dQw4w9WgXcQ")

      assert saida =~ ~s(src="https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ")
      assert saida =~ ~s(href="https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    end

    test "youtu.be e music.youtube também viram player" do
      assert html("https://youtu.be/dQw4w9WgXcQ") =~ "youtube-nocookie.com/embed/dQw4w9WgXcQ"

      assert html("https://music.youtube.com/watch?v=dQw4w9WgXcQ") =~
               "youtube-nocookie.com/embed/dQw4w9WgXcQ"
    end

    test "shorts não vira embed" do
      saida = html("https://www.youtube.com/shorts/dQw4w9WgXcQ")

      refute saida =~ "<iframe"
    end

    test "link do youtube no meio da frase fica link, não vira embed" do
      saida = html("vi isso no https://www.youtube.com/watch?v=dQw4w9WgXcQ ontem")

      refute saida =~ "<iframe"
      assert saida =~ "youtube.com/watch"
    end

    test "apple music vira player do embed.music.apple.com" do
      url = "https://music.apple.com/br/album/novo/1440841698?i=1440841701"
      saida = html(url)

      assert saida =~ ~s(src="https://embed.music.apple.com/br/album/novo/1440841698?i=1440841701")
    end

    test "spotify vira player, com ou sem /intl no caminho" do
      id = "4uLU6hMCjMI75M1A2tKUQC"

      assert html("https://open.spotify.com/track/#{id}") =~
               ~s(src="https://open.spotify.com/embed/track/#{id}")

      assert html("https://open.spotify.com/intl-pt/album/#{id}") =~
               ~s(src="https://open.spotify.com/embed/album/#{id}")
    end

    test "link comum sozinho continua link" do
      saida = html("https://exemplo.com/blog")

      refute saida =~ "<iframe"
      assert saida =~ ~s(href="https://exemplo.com/blog")
    end
  end
end
