defmodule Quintal.Passear do
  @moduledoc """
  A descoberta serendípita protagonizada pelo axô (spec 5.1, feature 9;
  spec 8.2, fluxo 4; marco m4).

  O passeio é um ritual, não um firehose de sugestões: uma descoberta por
  vez, sempre (briefing 5.6). Sorteia uma prosa do índice, fora do
  próprio canto de quem passeia. Sem ranqueamento, sem viés: o viés por
  arestas de depoimento é v1.5 (spec 5.1, feature 9).
  """

  import Ecto.Query

  alias Quintal.Prosa
  alias Quintal.Repo

  @doc """
  Uma prosa aleatória do índice, excluindo as da própria pessoa.

  `nil` quando o quintal ainda está vazio demais para passear.
  `ORDER BY RANDOM()` basta no alpha: o índice é pequeno e o passeio é
  ritual de uma carta por vez, não listagem.
  """
  @spec prosa_aleatoria(viewer_did :: String.t() | nil) :: Prosa.t() | nil
  def prosa_aleatoria(viewer_did) do
    Prosa
    |> fora_do_proprio_canto(viewer_did)
    |> order_by(fragment("RANDOM()"))
    |> limit(1)
    |> preload([:autor])
    |> Repo.one()
  end

  defp fora_do_proprio_canto(query, nil), do: query
  defp fora_do_proprio_canto(query, did), do: where(query, [p], p.autor_did != ^did)
end
