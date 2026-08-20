defmodule Quintal.Repo.Migrations.BlogrollsItemsDefault do
  use Ecto.Migration

  # cast_embed descarta `items: []` porque [] ja e o default do struct;
  # sem o change o insert omite a coluna. O default no banco cobre isso.
  def change do
    alter table(:blogrolls) do
      modify :items, :map, null: false, default: fragment("'[]'::jsonb")
    end
  end
end
