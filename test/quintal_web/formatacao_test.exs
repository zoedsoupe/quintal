defmodule QuintalWeb.FormatacaoTest do
  use ExUnit.Case, async: true

  alias QuintalWeb.Formatacao

  describe "data_curta/1" do
    test "ano corrente omite o ano" do
      hoje = DateTime.utc_now()
      data = %{hoje | month: 3, day: 12}
      assert Formatacao.data_curta(data) == "12/03"
    end

    test "ano passado mostra o ano curto" do
      {:ok, data} = DateTime.new(~D[2024-03-12], ~T[10:00:00])
      assert Formatacao.data_curta(data) == "12/03/24"
    end
  end

  describe "primeira_frase/1" do
    test "para no fim da primeira frase" do
      assert Formatacao.primeira_frase("o quintal acordou cedo. o café já tava na mesa.") ==
               "o quintal acordou cedo."
    end

    test "primeira linha ganha quando não tem ponto" do
      assert Formatacao.primeira_frase("uma linha só\noutra linha") == "uma linha só"
    end

    test "frase longa demais corta no espaço com reticências" do
      frase = "palavra " |> String.duplicate(30) |> String.trim()
      assert cortada = Formatacao.primeira_frase(frase)
      assert String.ends_with?(cortada, "…")
      assert String.length(cortada) <= 91
    end

    test "texto curto sem ponto volta inteiro" do
      assert Formatacao.primeira_frase("oi") == "oi"
    end
  end
end
