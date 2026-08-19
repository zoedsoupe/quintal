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

    # Boot-time session restore: off in test, where the sandbox owns the Repo.
    children =
      if Application.get_env(:quintal, :restore_sessions, true) do
        List.insert_at(children, -1, {Task, &AuthImpl.restore_all/0})
      else
        children
      end

    # Firehose consumer (m2): off in test, which feeds events by hand.
    children =
      if Application.get_env(:quintal, :ingestao, true) do
        List.insert_at(children, -1, Quintal.Ingestao)
      else
        children
      end

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
