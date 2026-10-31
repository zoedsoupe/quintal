defmodule Quintal.Passear do
  @moduledoc """
  A descoberta serendípita protagonizada pelo axô (spec 5.1, feature 9;
  spec 8.2, fluxo 4; marco m4).

  O passeio é um ritual, não um firehose de sugestões: uma descoberta por
  vez, sempre (briefing 5.6). Sorteia primeiro um canto (repo), depois
  uma prosa elegível daquele canto. O viés por arestas de depoimento é
  v1.5 (spec 5.1, feature 9).
  """

  import Ecto.Query

  alias Quintal.Prosa
  alias Quintal.Repo

  @doc """
  Sorteia primeiro um canto entre os autores com prosas elegíveis e
  depois uma prosa aleatória daquele canto. Exclui as prosas da própria
  pessoa, as respostas (uma resposta fora de contexto é uma carta ruim)
  e as uris já `vistas` nesta sessão de passeio, para o "de novo" não
  repetir carta.

  `nil` quando o quintal ainda está vazio demais para passear ou quando
  todas as prosas elegíveis já apareceram: cabe a quem chama zerar as
  `vistas` e recomeçar o ritual.
  `ORDER BY RANDOM()` em cada etapa basta no alpha: o índice é pequeno e
  o passeio é ritual de uma carta por vez, não listagem.
  """
  @spec prosa_aleatoria(viewer_did :: String.t() | nil, vistas :: [String.t()]) ::
          Prosa.t() | nil
  def prosa_aleatoria(viewer_did, vistas \\ []) do
    case autor_aleatorio(viewer_did, vistas) do
      nil ->
        nil

      autor_did ->
        Prosa
        |> prosas_elegiveis(viewer_did, vistas)
        |> where([p], p.autor_did == ^autor_did)
        |> order_by(fragment("RANDOM()"))
        |> limit(1)
        |> preload([:autor])
        |> Repo.one()
    end
  end

  defp autor_aleatorio(viewer_did, vistas) do
    autores =
      Prosa
      |> prosas_elegiveis(viewer_did, vistas)
      |> group_by([p], p.autor_did)
      |> select([p], p.autor_did)

    Repo.one(from(a in subquery(autores), order_by: fragment("RANDOM()"), limit: 1, select: a.autor_did))
  end

  defp prosas_elegiveis(query, viewer_did, vistas) do
    query
    |> where([p], is_nil(p.reply_root))
    |> fora_do_proprio_canto(viewer_did)
    |> fora_das_vistas(vistas)
  end

  defp fora_do_proprio_canto(query, nil), do: query
  defp fora_do_proprio_canto(query, did), do: where(query, [p], p.autor_did != ^did)

  defp fora_das_vistas(query, []), do: query
  defp fora_das_vistas(query, vistas), do: where(query, [p], p.uri not in ^vistas)
end
