defmodule Quintal.Auth.Dev do
  @moduledoc """
  `Quintal.Auth` de dev: uma sessão sintética pro did configurado, pra
  navegar as telas logadas sem passar pelo oauth.

  Selecionado só quando `config :quintal, :dev_identidade` existe, o que
  o `runtime.exs` só faz em dev (a partir de `QUINTAL_DEV_DID`). A sessão
  não tem repo real atrás: leitura vem do índice local, escrita no pds
  falha. Serve pra revisar, não pra prosear de verdade.
  """

  @behaviour Quintal.Auth

  alias Quintal.Identidade
  alias Quintal.Repo

  @impl true
  def authorize_url(_identifier), do: {:error, :dev_auth}

  @impl true
  def open_session(_pending, _params), do: {:error, :dev_auth}

  @impl true
  def current_session(did) when is_binary(did) do
    case Application.get_env(:quintal, :dev_identidade) do
      ^did -> {:ok, sessao(did)}
      _outro -> {:error, :sem_sessao}
    end
  end

  def current_session(_did), do: {:error, :sem_sessao}

  @impl true
  def logout(_did), do: :ok

  defp sessao(did) do
    %ProtoRune.Atproto.OAuth.Session{
      did: did,
      handle: handle(did),
      access_token: "dev",
      dpop_key: "dev",
      dpop_jwk: %{},
      service_url: "https://pds.example"
    }
  end

  defp handle(did) do
    case Repo.get(Identidade, did) do
      %Identidade{handle: handle} when is_binary(handle) -> handle
      _outro -> did
    end
  end
end
