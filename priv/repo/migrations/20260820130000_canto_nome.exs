defmodule Quintal.Repo.Migrations.CantoNome do
  use Ecto.Migration

  def change do
    alter table(:cantos) do
      add :nome, :string
    end
  end
end
