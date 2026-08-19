defmodule Quintal.Recado do
  @moduledoc """
  Uma entrada no livro de visitas de um canto (lexicon
  `place.quintal.canto.recado`, spec 10.2).

  Qualquer pessoa pode deixar recado em qualquer canto. O record vive no
  repo de quem escreveu; essa tabela é o índice local, upsert
  idempotente por `uri`.

  `oculto` é estado do appview, nunca do record: sua fala fica intacta
  no seu pds, a parede é minha (spec 5.1, feature 5). O upsert nunca
  toca nessa coluna, para o eco do firehose não desfazer a decisão do
  dono do canto.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:uri, :string, []}
  schema "recados" do
    field :autor_did, :string
    field :subject_did, :string
    field :texto, :string
    field :oculto, :boolean, default: false
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
  def changeset(recado, attrs) do
    recado
    |> cast(attrs, [:uri, :autor_did, :subject_did, :texto, :oculto, :created_at])
    |> validate_required([:uri, :autor_did, :subject_did, :texto, :created_at])
    |> validate_format(:uri, ~r/^at:\/\//)
    |> validate_length(:texto, max: 500)
    |> foreign_key_constraint(:autor_did)
    |> foreign_key_constraint(:subject_did)
  end
end
