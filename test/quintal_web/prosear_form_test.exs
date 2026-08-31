defmodule QuintalWeb.ProsearFormTest do
  use ExUnit.Case, async: true

  alias QuintalWeb.ProsearForm

  describe "limpa_links/1" do
    test "instagram, tiktok e shorts saem do texto" do
      texto = """
      olha isso https://www.instagram.com/p/abc123/ muito bom

      https://www.tiktok.com/@fulana/video/123

      e https://www.youtube.com/shorts/dQw4w9WgXcQ também
      """

      {limpo, true} = ProsearForm.limpa_links(texto)

      refute limpo =~ "instagram.com"
      refute limpo =~ "tiktok.com"
      refute limpo =~ "shorts/"
      assert limpo =~ "olha isso"
      assert limpo =~ "muito bom"
      assert limpo =~ "também"
    end

    test "texto sem link bloqueado passa intacto" do
      texto =
        "bom dia https://www.youtube.com/watch?v=dQw4w9WgXcQ e https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC"

      assert {^texto, false} = ProsearForm.limpa_links(texto)
    end

    test "linha que era só o link some, sem deixar vazio triplo" do
      {limpo, true} = ProsearForm.limpa_links("antes\n\nhttps://tiktok.com/@a/video/1\n\ndepois")

      assert limpo == "antes\n\ndepois"
    end
  end
end
