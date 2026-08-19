defmodule Quintal.Repo.Migrations.CreateM3Tables do
  use Ecto.Migration

  def change do
    create table(:recados, primary_key: false) do
      add :uri, :string, primary_key: true
      add :autor_did, references(:identidades, column: :did, type: :string), null: false
      add :subject_did, references(:identidades, column: :did, type: :string), null: false
      add :texto, :text, null: false
      add :oculto, :boolean, null: false, default: false
      add :created_at, :utc_datetime_usec, null: false
    end

    create index(:recados, [:subject_did, :created_at])

    create table(:depoimentos, primary_key: false) do
      add :uri, :string, primary_key: true
      add :autor_did, references(:identidades, column: :did, type: :string), null: false
      add :subject_did, references(:identidades, column: :did, type: :string), null: false
      add :texto, :text, null: false
      add :aceito, :boolean, null: true
      add :created_at, :utc_datetime_usec, null: false
    end

    create index(:depoimentos, [:subject_did])

    create table(:blogrolls, primary_key: false) do
      add :dono_did, references(:identidades, column: :did, type: :string), primary_key: true
      add :items, :map, null: false
      add :updated_at, :utc_datetime_usec, null: false
    end

    create table(:visitas_eventos) do
      add :dono_did, references(:identidades, column: :did, type: :string), null: false
      add :tipo, :string, null: false
      add :ref_uri, :string, null: false
      add :autor_did, references(:identidades, column: :did, type: :string)
      add :created_at, :utc_datetime_usec, null: false
    end

    create unique_index(:visitas_eventos, [:tipo, :ref_uri])
    create index(:visitas_eventos, [:dono_did, :created_at])

    create table(:visitas_lido_em, primary_key: false) do
      add :dono_did, references(:identidades, column: :did, type: :string), primary_key: true
      add :visto_em, :utc_datetime_usec, null: false
    end
  end
end
