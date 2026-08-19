defmodule Quintal.Blogroll do
  @moduledoc """
  O "quem eu leio" de um canto (lexicon `place.quintal.canto.blogroll`,
  spec 10.4): lista curada e pública de cantos. Numa plataforma sem
  contadores, o blogroll é o que é público por escolha (spec 5.1,
  feature 2).

  Record único com `literal:self`: uma escrita, lista limitada a 150
  cantos. Essa tabela é o índice local, upsert idempotente por
  `dono_did`.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @max_items 150

  @primary_key {:dono_did, :string, []}
  schema "blogrolls" do
    field :updated_at, :utc_datetime_usec

    embeds_many :items, Item, on_replace: :delete do
      field :did, :string
      field :note, :string
    end

    belongs_to :dono, Quintal.Identidade,
      foreign_key: :dono_did,
      references: :did,
      type: :string,
      define_field: false
  end

  @doc false
  def changeset(blogroll, attrs) do
    blogroll
    |> cast(attrs, [:dono_did, :updated_at])
    |> cast_embed(:items, with: &item_changeset/2)
    |> validate_required([:dono_did, :updated_at])
    |> validate_length(:items, max: @max_items)
    |> foreign_key_constraint(:dono_did)
  end

  defp item_changeset(item, attrs) do
    item
    |> cast(attrs, [:did, :note])
    |> validate_required([:did])
    |> validate_length(:note, max: 280)
  end
end
