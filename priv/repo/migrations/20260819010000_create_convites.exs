defmodule Quintal.Repo.Migrations.CreateConvites do
  use Ecto.Migration

  def change do
    create table(:convites, primary_key: false) do
      add :codigo, :string, primary_key: true
      add :criado_por, :string, null: false
      add :usado_por, :string
      add :criado_em, :utc_datetime_usec, null: false
      add :usado_em, :utc_datetime_usec
    end

    create index(:convites, [:criado_por])
  end
end
