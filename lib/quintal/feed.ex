defmodule Quintal.Feed do
  @moduledoc """
  O feed cronológico (spec 5.1, feature 3; marco m2): só prosas de quem
  a pessoa escolheu ler, em ordem de publicação, paginação por cursor.
  Sem ranqueamento em nenhuma camada: cronológico para sempre é a
  constituição do quintal (spec 2).

  O cursor é o par `(created_at, uri)` da última prosa da página,
  serializado como `"<unix_microsegundos>|<uri>"`: estável enquanto a
  vizinhança ganha prosas novas.
  """

  import Ecto.Query

  alias Quintal.Follow
  alias Quintal.Prosa
  alias Quintal.Repo

  @doc """
  Lista uma página do feed da pessoa, da prosa mais nova para a mais
  antiga.

  Opções: `:limit` (padrão 50) e `:cursor` (vem de `cursor/1`).
  """
  @spec list(did :: String.t(), opts :: keyword()) :: [Prosa.t()]
  def list(did, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Prosa
    |> join(:inner, [p], f in Follow, on: f.seguido_did == p.autor_did)
    |> where([_p, f], f.seguidor_did == ^did)
    |> a_partir_do_cursor(Keyword.get(opts, :cursor))
    |> order_by([p, _f], desc: p.created_at, desc: p.uri)
    |> limit(^limit)
    |> preload([p, _f], [:autor])
    |> Repo.all()
  end

  @doc "O cursor que retoma o feed logo depois dessa prosa."
  @spec cursor(Prosa.t()) :: String.t()
  def cursor(%Prosa{} = prosa) do
    "#{DateTime.to_unix(prosa.created_at, :microsecond)}|#{prosa.uri}"
  end

  defp a_partir_do_cursor(query, nil), do: query

  defp a_partir_do_cursor(query, cursor) when is_binary(cursor) do
    with [unix, uri] <- String.split(cursor, "|", parts: 2),
         {usec, ""} <- Integer.parse(unix),
         {:ok, created_at} <- DateTime.from_unix(usec, :microsecond) do
      where(
        query,
        [p, _f],
        p.created_at < ^created_at or (p.created_at == ^created_at and p.uri < ^uri)
      )
    else
      _cursor_invalido -> query
    end
  end
end
