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
end
