defmodule Quintal.VisitaEvento do
  @moduledoc """
  Um evento da página visitas (spec 7.5): alguém passou pelo canto.

  Tipos: `recado`, `resposta`, `novo_leitor`, `depoimento`, `leitura`.
  A tripla `(tipo, ref_uri, autor_did)` é única: a escrita otimista e o
  eco do firehose chegam como o mesmo evento duas vezes, e o índice
  dedupa. Para `leitura` isso significa uma marca por pessoa por prosa:
  a visita nunca é rastreada, é o leitor que a deixa, se quiser.

  Estado local do appview, nunca record: notificações quietas não saem
  de casa.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @tipos ~w(recado resposta novo_leitor depoimento leitura)

  schema "visitas_eventos" do
    field :dono_did, :string
    field :tipo, :string
    field :ref_uri, :string
    field :autor_did, :string
    field :created_at, :utc_datetime_usec

    belongs_to :autor, Quintal.Identidade,
      foreign_key: :autor_did,
      references: :did,
      type: :string,
      define_field: false
  end

  @doc false
  def changeset(evento, attrs) do
    evento
    |> cast(attrs, [:dono_did, :tipo, :ref_uri, :autor_did, :created_at])
    |> validate_required([:dono_did, :tipo, :ref_uri, :created_at])
    |> validate_inclusion(:tipo, @tipos)
    |> unique_constraint([:tipo, :ref_uri, :autor_did])
    |> foreign_key_constraint(:dono_did)
    |> foreign_key_constraint(:autor_did)
  end
end
