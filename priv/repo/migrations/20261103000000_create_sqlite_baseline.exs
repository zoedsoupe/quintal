defmodule Quintal.Repo.Migrations.CreateSqliteBaseline do
  use Ecto.Migration

  def change do
    create table(:identidades, primary_key: false) do
      add :did, :string, primary_key: true
      add :handle, :string, null: false
      add :pds_url, :string, null: false
      add :atualizado_em, :utc_datetime_usec, null: false
    end

    create unique_index(:identidades, [:handle])

    create table(:prosas, primary_key: false) do
      add :uri, :string, primary_key: true
      add :autor_did, references(:identidades, column: :did, type: :string), null: false
      add :cid, :string, null: false
      add :texto, :text, null: false
      add :tipo, :string
      add :reply_root, :string
      add :reply_parent, :string
      add :langs, {:array, :string}
      add :audio_blob, :map
      add :audio_alt, :text
      add :created_at, :utc_datetime_usec, null: false
      add :indexed_at, :utc_datetime_usec, null: false
    end

    create index(:prosas, [:autor_did, :created_at])
    create index(:prosas, [:reply_root])
    create index(:prosas, [:reply_parent])

    create table(:cantos, primary_key: false) do
      add :dono_did, references(:identidades, column: :did, type: :string), primary_key: true

      add :tema, :string, null: false, default: "papel"
      add :cor, :string
      add :blocos, {:array, :string}, null: false, default: []
      add :bio, :text
      add :links, :map
      add :updated_at, :utc_datetime_usec, null: false
      add :nome, :string
      add :avatar, :map
    end

    create table(:sessoes, primary_key: false) do
      add :did, :string, primary_key: true
      add :blob, :binary, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create table(:follows, primary_key: false) do
      add :seguidor_did, references(:identidades, column: :did, type: :string), null: false
      add :seguido_did, references(:identidades, column: :did, type: :string), null: false
      add :uri, :string, null: false
      add :created_at, :utc_datetime_usec, null: false
    end

    create unique_index(:follows, [:seguidor_did, :seguido_did])
    create unique_index(:follows, [:uri])
    create index(:follows, [:seguido_did])

    create table(:firehose_cursor, primary_key: false) do
      add :id, :integer, primary_key: true
      add :cursor, :bigint
    end

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
      add :aceito, :boolean
      add :created_at, :utc_datetime_usec, null: false
    end

    create index(:depoimentos, [:subject_did])

    create table(:blogrolls, primary_key: false) do
      add :dono_did, references(:identidades, column: :did, type: :string), primary_key: true

      add :items, :map, null: false, default: []
      add :updated_at, :utc_datetime_usec, null: false
    end

    create table(:visitas_eventos) do
      add :dono_did, references(:identidades, column: :did, type: :string), null: false
      add :tipo, :string, null: false
      add :ref_uri, :string, null: false
      add :autor_did, references(:identidades, column: :did, type: :string)
      add :created_at, :utc_datetime_usec, null: false
    end

    create unique_index(:visitas_eventos, [:tipo, :ref_uri, :autor_did])
    create index(:visitas_eventos, [:dono_did, :created_at])

    create table(:visitas_lido_em, primary_key: false) do
      add :dono_did, references(:identidades, column: :did, type: :string), primary_key: true

      add :visto_em, :utc_datetime_usec, null: false
    end

    create table(:convites, primary_key: false) do
      add :codigo, :string, primary_key: true
      add :criado_por, :string, null: false
      add :usado_por, :string
      add :criado_em, :utc_datetime_usec, null: false
      add :usado_em, :utc_datetime_usec
    end

    create index(:convites, [:criado_por])

    create table(:prosa_imagens, primary_key: false) do
      add :prosa_uri,
          references(:prosas, column: :uri, type: :string, on_delete: :delete_all),
          null: false

      add :posicao, :integer, null: false
      add :blob, :map, null: false
      add :alt, :text, null: false
    end

    create unique_index(:prosa_imagens, [:prosa_uri, :posicao])
  end
end
