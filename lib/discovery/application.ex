defmodule Discovery.Application do
  @moduledoc """
  Core OTP Application Supervisor for Discovery.
  """
  use Application

  alias Discovery.K8s.DeploymentController
  alias Discovery.Kubernetes.Watcher
  alias Discovery.Utils

  require Logger

  @impl true
  def start(_type, _args) do
    # Initialize high-speed in-memory ETS tables
    create_tables()

    children = [
      # Start the Telemetry supervisor
      DiscoveryWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Discovery.PubSub},
      # Start the Endpoint (http/https)
      DiscoveryWeb.Endpoint,
      # Start the Dynamic Kubernetes Watcher
      {Watcher, []},
      # Start the Dashboard Query Controller
      {DeploymentController, []}
    ]

    opts = [strategy: :one_for_one, name: Discovery.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    DiscoveryWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp create_tables do
    :ets.new(Utils.metadata_db(), [:set, :named_table, :public, read_concurrency: true])
    :ets.new(Utils.bridge_db(), [:set, :named_table, :public])
    :ets.new(Utils.idempotency_db(), [:set, :named_table, :public])
    Logger.info("Internal ETS tables initialized")
  end
end
