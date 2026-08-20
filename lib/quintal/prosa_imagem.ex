defmodule Quintal.ProsaImagem do
  @moduledoc """
  Uma imagem de prosa (lexicon `place.quintal.feed.prosa`, def
  `#imagem`, spec 10.1): a referência do blob no pds do autor e o alt
  obrigatório. Máximo de 4 por prosa, ordem guardada em `posicao`.

  O blob fica em jsonb no formato do lexicon (`%{"$type" => "blob",
  "ref" => %{"$link" => cid}, "mimeType" => _, "size" => _}`): é o que
  a firehose ecoa e o que a página precisa para montar a url de
  leitura.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  schema "prosa_imagens" do
    field :posicao, :integer
    field :blob, :map
    field :alt, :string

    belongs_to :prosa, Quintal.Prosa,
      foreign_key: :prosa_uri,
      references: :uri,
      type: :string,
      primary_key: true
  end

  @doc false
  def changeset(imagem, attrs) do
    imagem
    |> cast(attrs, [:prosa_uri, :posicao, :blob, :alt])
    |> validate_required([:prosa_uri, :posicao, :blob, :alt])
    |> validate_length(:alt, max: 1000)
    |> foreign_key_constraint(:prosa_uri)
  end
end
