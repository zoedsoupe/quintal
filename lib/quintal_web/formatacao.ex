defmodule QuintalWeb.Formatacao do
  @moduledoc """
  Formatação compartilhada das telas: tempo relativo em sussurro e o
  tipo da prosa como atom. Vive fora das LiveViews porque home, canto e
  visitas falam a mesma língua.
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
  O tipo é metadado interno, nunca rótulo (spec 10.1): no composer vira
  pill quieta, na prosa só a pergunta ganha ênfase visual.
  """
  def tipo(tipo) when tipo in ~w(nota pergunta cronica ensaio), do: String.to_atom(tipo)
  def tipo(_outro), do: :nota

  @resumo 600

  @doc """
  Trecho de prosa longa para o feed e o canto: crônicas e ensaios abrem
  em página própria, na lista entra só o começo. Corta no espaço mais
  perto do limite e devolve `{texto, cortou?}`.
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
end
