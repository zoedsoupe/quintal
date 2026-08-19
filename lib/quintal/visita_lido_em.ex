defmodule Quintal.VisitaLidoEm do
  @moduledoc """
  A marca da última passada pela página visitas (spec 7.5): o resumo
  conta só o que chegou depois desse instante, e zera a cada visita.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:dono_did, :string, []}
  schema "visitas_lido_em" do
    field :visto_em, :utc_datetime_usec
  end

  @doc false
  def changeset(lido_em, attrs) do
    lido_em
    |> cast(attrs, [:dono_did, :visto_em])
    |> validate_required([:dono_did, :visto_em])
    |> foreign_key_constraint(:dono_did)
  end
end
