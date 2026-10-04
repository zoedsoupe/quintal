defmodule Quintal.Repo.Migrations.CantoBlocosSemBioLinks do
  use Ecto.Migration

  @moduledoc """
  bio e links sao campos do canto, nunca blocos: a UI so rearrange as
  tres secoes que existem. Limpa as linhas antigas antes de o changeset
  passar a recusar nome fora da lista.
  """

  def up do
    execute(fn ->
      repo().query!("""
      UPDATE cantos
      SET blocos = (
        SELECT COALESCE(array_agg(b), ARRAY[]::text[]) FROM unnest(blocos) AS b
        WHERE b NOT IN ('bio', 'links')
      )
      WHERE blocos && ARRAY['bio', 'links']::varchar[]
      """)
    end)
  end

  def down, do: :ok
end
