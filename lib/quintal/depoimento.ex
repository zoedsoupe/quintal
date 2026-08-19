defmodule Quintal.Depoimento do
  @moduledoc """
  Um testemunho público sobre uma pessoa (lexicon
  `place.quintal.canto.depoimento`, spec 10.3): descoberta como ato de
  amor público (spec 5.1, feature 6).

  O record vive no repo de quem escreveu; essa tabela é o índice local,
  upsert idempotente por `uri`.

  Só aparece no canto do subject depois de aceito. Na v1 o aceite é
  estado local do appview (coluna `aceito`, `nil` até a decisão do dono
  do canto); o upsert nunca toca nessa coluna. Na v2, avaliar virar
  record, para o aceite também ser portátil.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:uri, :string, []}
  schema "depoimentos" do
    field :autor_did, :string
    field :subject_did, :string
    field :texto, :string
    field :aceito, :boolean
    field :created_at, :utc_datetime_usec

    belongs_to :autor, Quintal.Identidade,
      foreign_key: :autor_did,
      references: :did,
      type: :string,
      define_field: false

    belongs_to :subject, Quintal.Identidade,
      foreign_key: :subject_did,
      references: :did,
      type: :string,
      define_field: false
  end

  @doc false
  def changeset(depoimento, attrs) do
    depoimento
    |> cast(attrs, [:uri, :autor_did, :subject_did, :texto, :aceito, :created_at])
    |> validate_required([:uri, :autor_did, :subject_did, :texto, :created_at])
    |> validate_format(:uri, ~r/^at:\/\//)
    |> validate_length(:texto, max: 1000)
    |> foreign_key_constraint(:autor_did)
    |> foreign_key_constraint(:subject_did)
  end
end
