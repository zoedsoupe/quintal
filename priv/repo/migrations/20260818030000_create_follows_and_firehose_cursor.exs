defmodule Quintal.Repo.Migrations.CreateFollowsAndFirehoseCursor do
  use Ecto.Migration

  def change do
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
  end
end
