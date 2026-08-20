defmodule Quintal.Repo.Migrations.ProsasReplyParentIndex do
  use Ecto.Migration

  # respostas/2 filtra por reply_parent em toda página de prosa
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(:prosas, [:reply_parent], concurrently: true)
  end
end
