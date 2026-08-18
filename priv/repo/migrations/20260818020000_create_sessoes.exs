defmodule Quintal.Repo.Migrations.CreateSessoes do
  use Ecto.Migration

  def change do
    create table(:sessoes, primary_key: false) do
      add :did, :string, primary_key: true
      add :blob, :binary, null: false

      timestamps(type: :utc_datetime_usec)
    end
  end
end
