defmodule Discovery.K8s.DeploymentController do
  @moduledoc """
  Controller manager handles communications between the LiveView dashboard (Bridge) and the ETS databases.
  """
  use GenServer

  alias Discovery.Utils

  ### CLIENT FUNCTIONS ###

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get_deployment_data(app_name) do
    GenServer.call(__MODULE__, {"deployment_data", app_name})
  end

  def get_apps do
    GenServer.call(__MODULE__, "get_apps")
  end

  def insert_app(app_name) do
    GenServer.call(__MODULE__, {"insert_app", app_name})
  end

  def delete_app(app_name) do
    GenServer.call(__MODULE__, {"delete_app", app_name})
  end

  ### SERVER CALLBACKS ###

  def init(_args) do
    Process.send_after(self(), "populate_bridgedb", 5_000)
    {:ok, %{}}
  end

  def handle_call({"deployment_data", app_name}, _from, state) do
    data = lookup_deployments(app_name)
    {:reply, data, state}
  end

  def handle_call({"insert_app", app_name}, _from, state) do
    data = insert_app_to_bridgedb(app_name)
    {:reply, data, state}
  end

  def handle_call({"delete_app", app_name}, _from, state) do
    delete_app_from_ets(app_name)
    {:reply, {:ok, :app_deleted}, state}
  end

  def handle_call("get_apps", _from, state) do
    data =
      Utils.bridge_db()
      |> :ets.tab2list()
      |> Enum.map(fn {app_name, _details} -> app_name end)

    {:reply, data, state}
  end

  def handle_info("populate_bridgedb", state) do
    populate_bridgedb()
    {:noreply, state}
  end

  ### HELPER FUNCTIONS ###

  defp lookup_deployments(app_name) when is_binary(app_name) do
    case :ets.lookup(Utils.metadata_db(), {:all_pods, app_name}) do
      [] ->
        case :ets.lookup(Utils.metadata_db(), app_name) do
          [] ->
            %{}

          [{_app_name, details}] ->
            %{
              details.pod_name => %{
                "url" => details.url,
                "image" => details.image,
                "last_updated" => details.last_updated,
                "replicas" => 1,
                "ip" => details.ip,
                "port" => details.port,
                "active" => true
              }
            }
        end

      [{_all_pods_key, pods}] ->
        active_pod_name =
          case :ets.lookup(Utils.metadata_db(), app_name) do
            [{_app_name, %{pod_name: name}}] -> name
            _ -> nil
          end

        pods
        |> Enum.reduce(%{}, fn pod, acc ->
          Map.put(acc, pod.pod_name, %{
            "url" => pod.url,
            "image" => pod.image,
            "last_updated" => pod.last_updated,
            "replicas" => 1,
            "ip" => pod.ip,
            "port" => pod.port,
            "active" => pod.pod_name == active_pod_name
          })
        end)
    end
  end

  defp insert_app_to_bridgedb(app_name) do
    case app_name |> lookup_app() do
      nil ->
        :ets.insert(Utils.bridge_db(), {app_name, true})
        {:ok, :app_inserted}

      _ ->
        {:error, :app_present}
    end
  end

  defp delete_app_from_ets(app_name) do
    :ets.delete(Utils.bridge_db(), app_name)
    :ets.delete(Utils.metadata_db(), app_name)
  end

  defp lookup_app(app_name) do
    case :ets.lookup(Utils.bridge_db(), app_name) do
      [] -> nil
      [{_app_name, app_details}] -> app_details
    end
  end

  defp populate_bridgedb do
    :ets.tab2list(Utils.metadata_db())
    |> Enum.each(fn
      {app_name, _details} when is_binary(app_name) ->
        :ets.insert(Utils.bridge_db(), {app_name, true})

      _ ->
        :ok
    end)
  end
end
