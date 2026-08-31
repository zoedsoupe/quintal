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

  `tipo` é metadado interno (nota, pergunta, cronica, ensaio, lero), nunca um
  rótulo na interface. `pergunta` muda apenas a ênfase visual na thread.
  `lero` é a prosa falada: sem texto (o record leva `text` vazio), o áudio
  gravado na hora é o conteúdo inteiro.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @tipos ~w(nota pergunta cronica ensaio lero)

  @primary_key {:uri, :string, []}
  schema "prosas" do
    field :cid, :string
    field :texto, :string
    field :tipo, :string
    field :reply_root, :string
    field :reply_parent, :string
    field :langs, {:array, :string}
    field :audio_blob, :map
    field :audio_alt, :string
    field :created_at, :utc_datetime_usec
    field :indexed_at, :utc_datetime_usec

    belongs_to :autor, Quintal.Identidade,
      foreign_key: :autor_did,
      references: :did,
      type: :string

    has_many :imagens, Quintal.ProsaImagem,
      foreign_key: :prosa_uri,
      references: :uri,
      preload_order: [asc: :posicao]
  end

  @doc false
  def changeset(prosa, attrs) do
    # empty_values: [] porque o texto do lero é "" de propósito (o
    # lexicon exige o campo text); o cast padrão viraria nil e a
    # coluna NOT NULL derrubaria o insert
    prosa
    |> cast(
      attrs,
      [
        :uri,
        :autor_did,
        :cid,
        :texto,
        :tipo,
        :reply_root,
        :reply_parent,
        :langs,
        :audio_blob,
        :audio_alt,
        :created_at,
        :indexed_at
      ], empty_values: [])
    |> validate_required([:uri, :autor_did, :cid, :created_at, :indexed_at])
    |> validate_format(:uri, ~r/^at:\/\//)
    |> validate_length(:texto, max: 10_000)
    |> validate_inclusion(:tipo, @tipos)
    |> valida_lero()
    |> foreign_key_constraint(:autor_did)
  end

  # lero é a prosa falada: o texto fica vazio no record (o lexicon exige
  # o campo) e o áudio é obrigatório. nos outros tipos o texto é o
  # conteúdo e não pode faltar
  defp valida_lero(changeset) do
    if get_field(changeset, :tipo) == "lero" do
      validate_required(changeset, [:audio_blob])
    else
      validate_required(changeset, [:texto])
    end
  end
end
