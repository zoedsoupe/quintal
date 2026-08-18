defmodule Quintal.Repo.Migrations.CreateIndexTables do
  use Ecto.Migration

  def change do
    create table(:identidades, primary_key: false) do
      add :did, :string, primary_key: true
      add :handle, :string, null: false
      add :pds_url, :string, null: false
      add :atualizado_em, :utc_datetime_usec, null: false
    end

    create index(:identidades, [:handle], unique: true)

    create table(:prosas, primary_key: false) do
      add :uri, :string, primary_key: true
      add :autor_did, references(:identidades, column: :did, type: :string), null: false
      add :cid, :string, null: false
      add :texto, :text, null: false
      add :tipo, :string
      add :reply_root, :string
      add :reply_parent, :string
      add :langs, {:array, :string}
      add :created_at, :utc_datetime_usec, null: false
      add :indexed_at, :utc_datetime_usec, null: false
    end

    create index(:prosas, [:autor_did, :created_at])
    create index(:prosas, [:reply_root])

    create table(:cantos, primary_key: false) do
      add :dono_did, references(:identidades, column: :did, type: :string), primary_key: true
      add :tema, :string, null: false, default: "papel"
      add :cor, :string
      add :blocos, :map, null: false
      add :bio, :text
      add :links, :map
      add :updated_at, :utc_datetime_usec, null: false
    end
  end
end
