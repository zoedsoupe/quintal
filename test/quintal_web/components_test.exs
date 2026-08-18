defmodule QuintalWeb.ComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import QuintalWeb.Components

  test "botao renderiza a variante como classe" do
    assigns = %{}

    html = rendered_to_string(~H[<.botao variante={:fantasma}>prosear</.botao>])

    assert html =~ ~s(class="botao botao--fantasma")
    assert html =~ "prosear"
  end

  test "campo com name e value soltos" do
    assigns = %{}

    html = rendered_to_string(~H[<.campo name="bio" label="bio" value="oi" />])

    assert html =~ ~s(class="campo__label")
    assert html =~ ~s(name="bio")
    assert html =~ ~s(value="oi")
  end

  test "campo vira textarea com area: true" do
    assigns = %{}

    html = rendered_to_string(~H[<.campo name="texto" area />])

    assert html =~ "<textarea"
    assert html =~ ~s(class="campo__area")
  end

  test "prosa do tipo pergunta ganha ênfase visual" do
    assigns = %{}

    normal = rendered_to_string(~H[<.prosa autor="alice" data="hoje">texto</.prosa>])
    pergunta = rendered_to_string(~H[<.prosa autor="alice" data="hoje" tipo={:pergunta}>?</.prosa>])

    refute normal =~ "prosa--pergunta"
    assert pergunta =~ "prosa--pergunta"
  end

  test "vazio mostra o axô e o título" do
    assigns = %{}

    html = rendered_to_string(~H[<.vazio titulo="por aqui ainda tá quieto" />])

    assert html =~ ~s(class="axo")
    assert html =~ "por aqui ainda tá quieto"
  end
end
