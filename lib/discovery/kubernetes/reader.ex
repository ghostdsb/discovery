defmodule Discovery.Kubernetes.Reader do
  @moduledoc """
  MetadataDB read operations for client route resolution.
  """
  alias Discovery.Utils

  @doc """
  Returns the active stable routing url for a given app name.
  """
  @spec get_endpoint(String.t()) :: String.t()
  def get_endpoint(app_name) do
    case :ets.lookup(Utils.metadata_db(), app_name) do
      [{^app_name, details}] ->
        details.url

      _ ->
        ""
    end
  end

  @doc """
  Returns list of active deployments for a given app name.
  """
  @spec get_deployments(String.t()) :: list()
  def get_deployments(app_name) do
    case :ets.lookup(Utils.metadata_db(), app_name) do
      [{^app_name, details}] ->
        # Return a list of active pods formatted for lookups
        [details]

      _ ->
        []
    end
  end
end
