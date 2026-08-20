defmodule Quintal.Repo.Migrations.CreateProsaImagens do
  use Ecto.Migration

  def change do
    create table(:prosa_imagens, primary_key: false) do
      add :prosa_uri, references(:prosas, column: :uri, type: :string, on_delete: :delete_all),
        null: false

      add :posicao, :integer, null: false
      add :blob, :map, null: false
      add :alt, :text, null: false
    end

    create unique_index(:prosa_imagens, [:prosa_uri, :posicao])
  end
end
