defmodule Quintal.Follow do
  @moduledoc """
  Um follow do grafo próprio do quintal (lexicon
  `place.quintal.graph.follow`, spec 10.6): separado do bluesky de
  propósito, ninguém quer seus follows de lá vazando para a lista de
  leitura daqui.

  Sem contadores, em nenhuma direção: a vizinhança é sua e de mais
  ninguém (spec 5.1). O que é público por escolha é o blogroll.

  Chave composta `(seguidor_did, seguido_did)`; a `uri` do record fica
  guardada para processar deletes que chegam pela firehose (spec 8.4).
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  schema "follows" do
    field :uri, :string
    field :created_at, :utc_datetime_usec

    belongs_to :seguidor, Quintal.Identidade,
      foreign_key: :seguidor_did,
      references: :did,
      type: :string,
      primary_key: true

    belongs_to :seguido, Quintal.Identidade,
      foreign_key: :seguido_did,
      references: :did,
      type: :string,
      primary_key: true
  end

  @doc false
  def changeset(follow, attrs) do
    follow
    |> cast(attrs, [:seguidor_did, :seguido_did, :uri, :created_at])
    |> validate_required([:seguidor_did, :seguido_did, :uri, :created_at])
    |> validate_format(:uri, ~r/^at:\/\//)
    |> unique_constraint([:seguidor_did, :seguido_did])
    |> unique_constraint(:uri)
    |> foreign_key_constraint(:seguidor_did)
    |> foreign_key_constraint(:seguido_did)
  end
end
