defmodule MovingPlanner.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MovingPlannerWeb.Telemetry,
      MovingPlanner.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:moving_planner, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:moving_planner, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: MovingPlanner.PubSub},
      # Start a worker by calling: MovingPlanner.Worker.start_link(arg)
      # {MovingPlanner.Worker, arg},
      {MovingPlanner.MCP.Server, transport: :streamable_http},
      # Start to serve requests, typically the last entry
      MovingPlannerWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MovingPlanner.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MovingPlannerWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
