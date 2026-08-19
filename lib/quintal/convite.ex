defmodule Quintal.Convite do
  @moduledoc """
  Um código de convite (spec 6.1): um código, uma entrada, um uso.

  Estado local do appview, nunca record: o convite é controle de portaria
  do alpha fechado, não faz parte do protocolo. `criado_por` guarda o did
  de quem gerou ou a string `"admin"` para códigos avulsos da portaria.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:codigo, :string, []}
  schema "convites" do
    field :criado_por, :string
    field :usado_por, :string
    field :criado_em, :utc_datetime_usec
    field :usado_em, :utc_datetime_usec
  end

  @doc false
  def changeset(convite, attrs) do
    convite
    |> cast(attrs, [:codigo, :criado_por, :usado_por, :criado_em, :usado_em])
    |> validate_required([:codigo, :criado_por, :criado_em])
    |> unique_constraint(:codigo)
  end
end
