defmodule Quintal.Identidade do
  @moduledoc """
  Uma identidade atproto indexada: did, handle atual e pds de origem.

  A fonte de verdade é o repo da pessoa no pds dela. Essa tabela é o
  índice local do quintal (spec 8.4), atualizado pela ingestão do
  firehose e invalidado pelos eventos `identity` e `handle`.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  alias Quintal.Repo

  @primary_key {:did, :string, []}
  schema "identidades" do
    field :handle, :string
    field :pds_url, :string
    field :atualizado_em, :utc_datetime_usec

    has_many :prosas, Quintal.Prosa, foreign_key: :autor_did, references: :did
    has_one :canto, Quintal.Canto, foreign_key: :dono_did, references: :did
  end

  @doc false
  def changeset(identidade, attrs) do
    identidade
    |> cast(attrs, [:did, :handle, :pds_url, :atualizado_em])
    |> validate_required([:did, :handle, :pds_url, :atualizado_em])
    |> validate_format(:did, ~r/^did:(plc|web):/)
    |> unique_constraint(:handle)
  end

  @doc """
  A identidade por handle ou por did, como o leitor escreveu.
  `{:error, :canto_desconhecido}` quando não existe: nos três contextos
  que recebem `@fulana`, identidade que não existe é a mesma recusa.
  """
  @spec buscar(String.t()) :: {:ok, %__MODULE__{}} | {:error, :canto_desconhecido}
  def buscar(identificador) do
    case Repo.one(from i in __MODULE__, where: i.handle == ^identificador or i.did == ^identificador) do
      %__MODULE__{} = identidade -> {:ok, identidade}
      nil -> {:error, :canto_desconhecido}
    end
  end
end
