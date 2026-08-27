defmodule Quintal.Repo.Migrations.CantoAvatar do
  use Ecto.Migration

  def change do
    alter table(:cantos) do
      add :avatar, :map
    end
  end
end
