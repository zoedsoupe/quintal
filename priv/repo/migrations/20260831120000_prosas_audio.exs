defmodule Quintal.Repo.Migrations.ProsasAudio do
  use Ecto.Migration

  def change do
    alter table(:prosas) do
      add :audio_blob, :map
      add :audio_alt, :text
    end
  end
end
