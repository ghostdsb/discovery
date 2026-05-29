defmodule Discovery.Application do
  @moduledoc false
  use Application

  alias Discovery.K8s.DeploymentController
  alias Discovery.Orchestrator.Controller, as: DeployController
  alias Discovery.Kubernetes.Client
  alias Discovery.Orchestrator.Pipeline
  alias Discovery.Scheduler
  alias Discovery.Utils

  require Logger

  @impl true
  def start(_type, _args) do
    # Initialize ETS tables
    create_tables()

    git_access_token = Application.get_env(:discovery, :git_access_token)

    children = [
      # Start the Telemetry supervisor
      DiscoveryWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Discovery.PubSub},
      # Start the Endpoint (http/https)
      DiscoveryWeb.Endpoint,
      {Client, []},
      {DeploymentController, []},
      {DeployController, []},
      {Pipeline, gitops_opts(git_access_token)},
      Scheduler
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
    :ets.new(Utils.metadata_db(), [:set, :named_table, :public])
    :ets.new(Utils.bridge_db(), [:set, :named_table, :public])
    :ets.new(Utils.idempotency_db(), [:set, :named_table, :public])
    Logger.info("Internal ETS tables initialized")
  end

  defp gitops_opts(token) do
    [
      repo_url: "git@github.com:discovery/discovery-k8s.git",
      token: token,
      local_path: "/tmp/discovery-k8s",
      use_pr: false,
      write_layout: :env_first,
      env_root_map: %{"dev" => "dev", "staging" => "staging", "prod" => "prod"},
      base_dir_name: "base",
      file_names: %{
        deployment: "deploy.yml",
        configmap: "configmap.yml",
        secret: "secret.yml",
        service: "service.yml",
        ingress: "ingress.yml"
      }
    ]
  end
end
