defmodule Quintal.Application do
  @moduledoc false

  use Application

  alias Quintal.Auth.ProtoRune, as: AuthImpl
  alias Quintal.Auth.SessionRegistry
  alias Quintal.Auth.SessionSupervisor

  @impl true
  def start(_type, _args) do
    children = [
      Quintal.Repo,
      {Phoenix.PubSub, name: Quintal.PubSub},
      {Registry, keys: :unique, name: SessionRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: SessionSupervisor},
      {Task.Supervisor, name: Quintal.TaskSupervisor},
      QuintalWeb.Endpoint
    ]

    children =
      if Quintal.env() == :test,
        do: children,
        else: children ++ [{Task, &AuthImpl.restore_all/0}, Quintal.Ingestao]

    opts = [strategy: :one_for_one, name: Quintal.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    QuintalWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
