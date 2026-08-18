defmodule Quintal.Repo.Migrations.CantoBlocosNativeArray do
  use Ecto.Migration

  def change do
    alter table(:cantos) do
      remove :blocos
      add :blocos, {:array, :string}, null: false, default: []
    end
  end
end
