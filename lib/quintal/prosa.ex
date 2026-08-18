defmodule Quintal.Prosa do
  @moduledoc """
  A unidade de escrita do quintal (lexicon `place.quintal.feed.prosa`,
  spec 10.1).

  O record vive no repo da pessoa, no pds dela. Essa tabela é o índice
  local: upsert idempotente por `uri`, porque a escrita otimista e o eco
  do firehose chegam como o mesmo evento duas vezes (spec 8.2).

  Respostas são prosas comuns com `reply_root` e `reply_parent`
  preenchidos: a nota rápida e a resposta ensaio diferem só na
  apresentação, nunca na estrutura.

  `tipo` é metadado interno (nota, pergunta, cronica, ensaio), nunca um
  rótulo na interface. `pergunta` muda apenas a ênfase visual na thread.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @tipos ~w(nota pergunta cronica ensaio)

  @primary_key {:uri, :string, []}
  schema "prosas" do
    field :cid, :string
    field :texto, :string
    field :tipo, :string
    field :reply_root, :string
    field :reply_parent, :string
    field :langs, {:array, :string}
    field :created_at, :utc_datetime_usec
    field :indexed_at, :utc_datetime_usec

    belongs_to :autor, Quintal.Identidade,
      foreign_key: :autor_did,
      references: :did,
      type: :string
  end

  @doc false
  def changeset(prosa, attrs) do
    prosa
    |> cast(attrs, [
      :uri,
      :autor_did,
      :cid,
      :texto,
      :tipo,
      :reply_root,
      :reply_parent,
      :langs,
      :created_at,
      :indexed_at
    ])
    |> validate_required([:uri, :autor_did, :cid, :texto, :created_at, :indexed_at])
    |> validate_format(:uri, ~r/^at:\/\//)
    |> validate_length(:texto, max: 10_000)
    |> validate_inclusion(:tipo, @tipos)
    |> foreign_key_constraint(:autor_did)
  end
end
