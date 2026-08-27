defmodule Quintal.Canto do
  @moduledoc """
  A configuração do canto de uma pessoa (lexicon
  `place.quintal.canto.config`, spec 10.5).

  Guarda o preset de tema (papel, madrugada, gloss), a cor de acento
  opcional dentro do preset, a ordem dos blocos do arrastar e soltar, a
  bio e os links. Bloco ausente em `blocos` está escondido. A dupla
  luminosidade do papel (dia e lamparina) é resolvida na renderização,
  não no dado.

  O `nome` é de exibição e local do appview: não mora no record, não
  viaja pela firehose, só o quintal mostra. O handle continua sendo o
  endereço oficial da casa.

  O record correspondente usa `literal:self`: existe no máximo um canto
  por pessoa, e a decoração também é portátil entre appviews.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @temas ~w(papel madrugada gloss)
  @blocos ~w(bio prosas recados quem-eu-leio links)

  @primary_key {:dono_did, :string, []}
  schema "cantos" do
    field :tema, :string, default: "papel"
    field :cor, :string
    field :blocos, {:array, :string}
    field :bio, :string
    field :avatar, :map
    field :nome, :string
    field :updated_at, :utc_datetime_usec

    embeds_many :links, Link, on_replace: :delete do
      field :titulo, :string
      field :url, :string
    end

    belongs_to :dono, Quintal.Identidade,
      foreign_key: :dono_did,
      references: :did,
      type: :string,
      define_field: false
  end

  @doc false
  def changeset(canto, attrs) do
    canto
    |> cast(attrs, [:dono_did, :tema, :cor, :blocos, :bio, :avatar, :nome, :updated_at])
    |> cast_embed(:links, with: &link_changeset/2)
    |> validate_required([:dono_did, :tema, :blocos, :updated_at])
    |> validate_inclusion(:tema, @temas)
    |> validate_subset(:blocos, @blocos)
    |> validate_format(:cor, ~r/^#[0-9a-fA-F]{6}$/)
    |> validate_length(:bio, max: 2000)
    |> validate_length(:nome, max: 60)
    |> foreign_key_constraint(:dono_did)
  end

  defp link_changeset(link, attrs) do
    link
    |> cast(attrs, [:titulo, :url])
    |> validate_required([:titulo, :url])
    |> validate_length(:titulo, max: 60)
    |> validate_format(:url, ~r/^https?:\/\//)
  end
end
