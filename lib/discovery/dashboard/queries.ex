defmodule Discovery.Dashboard.Queries do
  @moduledoc """
  Manages the communications of liveview with the backend read layers.
  """
  alias Discovery.K8s.DeploymentController

  @doc """
  Fetches the active deployment data of an app from metadatadb ets
  """
  @spec get_deployment_data(String.t()) :: list()
  def get_deployment_data(app_name) do
    app_name
    |> DeploymentController.get_deployment_data()
    |> Enum.map(fn {name, value} -> Map.put(value, "name", name) end)
    |> Enum.sort(fn dep1, dep2 ->
      DateTime.compare(dep1["last_updated"], dep2["last_updated"]) === :gt
    end)
  end

  @doc """
  Fetches list of all apps tracked in bridgedb ets
  """
  @spec get_apps :: list()
  def get_apps do
    DeploymentController.get_apps()
    |> Enum.map(fn app_name ->
      deployment_count =
        app_name
        |> get_deployment_data()
        |> Enum.count()

      %{
        app_name: app_name,
        deployments: deployment_count,
        url: "#{Application.get_env(:discovery, :base_url)}/api/endpoint?app_name=#{app_name}"
      }
    end)
  end

  @doc """
  Inserts the app name into bridgedb ets to begin registry tracking
  """
  @spec create_app(String.t()) :: {:ok, :app_inserted} | {:error, :app_present}
  def create_app(app_name) do
    app_name
    |> DeploymentController.insert_app()
  end

  @doc """
  Deletes an app name and its associated endpoints from the registry
  """
  @spec delete_app(String.t()) :: {:ok, list()} | {:error, any()}
  def delete_app(app_name) do
    app_name
    |> DeploymentController.delete_app()
  end

  @doc """
  Creates or updates a mock deployment in local sandbox mode.
  """
  @spec create_deployment(map()) :: {:ok, map()} | {:error, term()}
  def create_deployment(params) do
    app_name = params.app_name
    image = params.app_image || "stub-image:latest"
    uid = Discovery.Utils.get_uid()
    deployment_name = "#{app_name}-#{uid}"

    # In sandbox/stub mode, write mock files to data/discovery/ so watcher picks it up.
    if Application.get_env(:discovery, :connection_method) == :stub do
      app_dir = "data/discovery/#{app_name}"
      depl_dir = "#{app_dir}/#{deployment_name}"
      File.mkdir_p!(depl_dir)

      # Write deployment yml
      deploy_content = """
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: #{deployment_name}
      spec:
        replicas: 1
        template:
          spec:
            containers:
              - name: #{app_name}
                image: #{image}
      """
      File.write!(Path.join(depl_dir, "deploy.yml"), deploy_content)

      # Write ingress.yml if not exists
      ingress_path = Path.join(app_dir, "ingress.yml")
      unless File.exists?(ingress_path) do
        ingress_content = """
        apiVersion: networking.k8s.io/v1
        kind: Ingress
        metadata:
          name: #{app_name}
        spec:
          rules:
            - host: #{app_name}.local
              http:
                paths:
                  - path: /#{uid}
                    backend:
                      service:
                        name: #{deployment_name}
                        port:
                          number: 80
        """
        File.write!(ingress_path, ingress_content)
      end
    end

    {:ok, %{deployment_name: deployment_name}}
  end
end
