defmodule Quintal.Auth.Sessao do
  @moduledoc """
  Sessão OAuth atproto persistida, indexada por did.

  O `blob` é a sessão serializada e cifrada por
  `ProtoRune.Security.Crypto` (AES-256-GCM): access token, refresh
  token e a chave privada DPoP nunca tocam o banco em claro. O cookie
  da pessoa carrega apenas o did.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:did, :string, []}
  schema "sessoes" do
    field :blob, :binary

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(sessao, attrs) do
    sessao
    |> cast(attrs, [:did, :blob])
    |> validate_required([:did, :blob])
    |> validate_format(:did, ~r/^did:(plc|web):/)
  end
end
