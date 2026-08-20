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

    test "menção vira link pro perfil no bsky.app" do
      saida = html("oi @alice.bsky.social")

      assert saida =~ ~s(<a href="https://bsky.app/profile/alice.bsky.social">@alice.bsky.social</a>)
    end

    test "menção com acento antes não quebra o link" do
      assert html("é @alice.bsky.social") =~ "bsky.app/profile/alice.bsky.social"
    end

    test "menção dentro de código ou link fica quieta" do
      saida = html("`@a.bc` [x @b.cd](https://z.co)")

      refute saida =~ "bsky.app/profile"
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
      assert saida =~ "bsky.app/profile/alice.bsky.social"
    end
  end
end
