defmodule Quintal.Repo.Migrations.VisitasEventosUniqueComAutor do
  use Ecto.Migration

  def change do
    # leituras: varias pessoas marcam a mesma prosa como lida, entao o
    # dedup passa a ser por (tipo, ref_uri, autor_did). para os outros
    # tipos a ref_uri ja e o record do autor, entao o comportamento
    # nao muda.
    drop unique_index(:visitas_eventos, [:tipo, :ref_uri])
    create unique_index(:visitas_eventos, [:tipo, :ref_uri, :autor_did])
  end
end
