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

end
