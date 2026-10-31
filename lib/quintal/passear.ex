defmodule Quintal.Passear do
  @moduledoc """
  A descoberta serendípita protagonizada pelo axô (spec 5.1, feature 9;
  spec 8.2, fluxo 4; marco m4).

  Passear apresenta um canto por vez, sem transformar a descoberta num
  feed de prosas. Cantos já vistos ficam fora do sorteio até a pessoa
  escolher recomeçar o passeio.
  """

  import Ecto.Query

  alias Quintal.Identidade
  alias Quintal.Repo

  @doc "Sorteia um canto, excluindo a própria identidade e os cantos já vistos."
  @spec canto_aleatorio(viewer_did :: String.t() | nil, vistos :: [String.t()]) ::
          Identidade.t() | nil
  def canto_aleatorio(viewer_did, vistos \\ []) do
    Identidade
    |> fora_do_proprio_canto(viewer_did)
    |> fora_dos_vistos(vistos)
    |> order_by(fragment("RANDOM()"))
    |> limit(1)
    |> Repo.one()
  end

  defp fora_do_proprio_canto(query, nil), do: query
  defp fora_do_proprio_canto(query, did), do: where(query, [i], i.did != ^did)

  defp fora_dos_vistos(query, []), do: query
  defp fora_dos_vistos(query, vistos), do: where(query, [i], i.did not in ^vistos)
end
