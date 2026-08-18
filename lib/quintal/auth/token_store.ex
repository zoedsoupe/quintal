defmodule Quintal.Auth.TokenStore do
  @moduledoc """
  Backend `ProtoRune.Security.TokenStore` sobre a tabela `sessoes`.

  Os blobs chegam aqui já cifrados por `ProtoRune.Security.Crypto`;
  este módulo só persiste e recupera binários opacos por did.
  """

  @behaviour ProtoRune.Security.TokenStore

  import Ecto.Query, only: [from: 2]

  alias Quintal.Auth.Sessao
  alias Quintal.Repo

  @impl true
  def put(did, blob, _opts) when is_binary(did) and is_binary(blob) do
    %Sessao{}
    |> Sessao.changeset(%{did: did, blob: blob})
    |> Repo.insert(
      on_conflict: [set: [blob: blob, updated_at: DateTime.utc_now()]],
      conflict_target: :did
    )
    |> case do
      {:ok, _sessao} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def fetch(did, _opts) when is_binary(did) do
    case Repo.get(Sessao, did) do
      %Sessao{blob: blob} -> {:ok, blob}
      nil -> {:error, :not_found}
    end
  end

  @impl true
  def delete(did, _opts) when is_binary(did) do
    Repo.delete_all(from s in Sessao, where: s.did == ^did)
    :ok
  end

  @doc "Lista os dids com sessão persistida. Usado no restore de boot."
  @spec all() :: [String.t()]
  def all, do: Repo.all(from s in Sessao, select: s.did)
end
