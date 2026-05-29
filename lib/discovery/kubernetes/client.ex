defmodule Discovery.Kubernetes.Client do
  @moduledoc """
  Polls k8 and process the deployment data from k8s and push to ETS, as a kv pair,
  where key will be the app id and value will be the metadata of app.
  """

  require Logger

  alias Discovery.Kubernetes.Manifests.{
    Deployment,
    Ingress
  }

  alias Discovery.Utils
  use GenServer

  @type t :: %__MODULE__{
          conn_ref: nil | map(),
          deployment_info: nil | map()
        }

  defstruct(
    conn_ref: nil,
    deployment_info: %{}
  )

  @k8_fetch_interval 5_000

  ## Client functions ##
  @spec start_link(any()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get_state do
    GenServer.call(__MODULE__, "get-state")
  end

  def get_conn do
    GenServer.call(__MODULE__, "get-conn")
  end

  ## Server callbacks ##
  @impl true
  def init(_init_arg) do
    Logger.info("Engine builder started.")
    # create a k8 connection
    # Then start polling and building
    k8_conn_ref = connect_to_k8()
    state = __MODULE__.__struct__(conn_ref: k8_conn_ref)
    Logger.info("Initial Builder state => #{inspect(state)}")
    Process.send_after(self(), "fetch_deployment_data", @k8_fetch_interval - 2_000)
    {:ok, state}
  end

  @impl true
  def handle_call("get-state", _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call("get-conn", _from, state) do
    {:reply, state.conn_ref, state}
  end

  @impl true
  def handle_info("fetch_deployment_data", state) do
    state = %{state | deployment_info: %{}}
    # state |> IO.inspect(label: "State for fetch deployment data")
    updated_state = build_metadata(state)
    Process.send_after(self(), "fetch_deployment_data", @k8_fetch_interval)
    {:noreply, updated_state}
  end

  ## Utilities functions ##

  # Connects to Kubernetes
  @spec connect_to_k8() :: any()
  defp connect_to_k8 do
    case Application.get_env(:discovery, :connection_method) do
      :stub ->
        Logger.info("K8 connection running in :stub sandbox mode")
        :stub_connection

      _ ->
        # Try service account first (in-cluster)
        case K8s.Conn.from_service_account() do
          {:ok, conn} ->
            Logger.info("K8 connection success (In-Cluster)")
            conn

          _ ->
            # Fallback to local kubeconfig
            case K8s.Conn.from_file("~/.kube/config") do
              {:ok, conn} ->
                Logger.info("K8 connection success (Local Kubeconfig)")
                conn

              {:error, reason} ->
                Logger.error("Error while K8 connection: #{inspect(reason)}")
                nil
            end
        end
    end
  end

  # By the end, metadata of apps will be updated in metadata_db (ETS).
  @spec build_metadata(__MODULE__.t()) :: any()
  defp build_metadata(%{conn_ref: nil} = state), do: state

  defp build_metadata(%{conn_ref: :stub_connection} = state) do
    fetch_stub_deployment_list()
    |> update_metadata_db(state)
  end

  defp build_metadata(state) do
    fetch_deployment_list(state.conn_ref)
    |> update_metadata_db(state)
  end

  # Fetching the entire deployment data as a list for the namespace
  # [{Deployment_A, Deployment_B...., Deployment_N}]

  @spec fetch_deployment_list(K8s.Conn.t()) :: list(map())
  defp fetch_deployment_list(conn) do
    Deployment.fetch_k8_deployments(conn)
    |> case do
      {:ok, data} ->
        data["items"]

      {:error, reason} ->
        IO.puts("Error on fetching deployment, due to #{inspect(reason)}")
        nil
    end
  end

  defp fetch_stub_deployment_list do
    root = "data/discovery"

    if File.dir?(root) do
      File.ls!(root)
      |> Enum.filter(fn name -> File.dir?(Path.join(root, name)) and name != "namespace" end)
      |> Enum.flat_map(fn app_name ->
        app_dir = Path.join(root, app_name)

        File.ls!(app_dir)
        |> Enum.filter(fn item ->
          File.dir?(Path.join(app_dir, item)) and String.contains?(item, "#{app_name}-")
        end)
        |> Enum.map(fn deployment_name ->
          deployment_dir = Path.join(app_dir, deployment_name)
          deploy_yaml_path = Path.join(deployment_dir, "deploy.yml")

          # Fallback to config files in pipeline working dir
          deploy_yaml_path =
            if File.exists?(deploy_yaml_path),
              do: deploy_yaml_path,
              else: Path.join(deployment_dir, "deployment.yml")

          # Read image & replicas from the yml file
          case File.exists?(deploy_yaml_path) do
            true ->
              case YamlElixir.read_from_file(deploy_yaml_path, atoms: false) do
                {:ok, deploy_map} ->
                  container =
                    get_in(deploy_map, ["spec", "template", "spec", "containers"]) |> List.first() ||
                      %{"image" => "stub:latest"}

                  replicas = get_in(deploy_map, ["spec", "replicas"]) || 1

                  %{
                    "metadata" => %{
                      "name" => deployment_name,
                      "annotations" => %{"app_id" => app_name}
                    },
                    "spec" => %{
                      "template" => %{
                        "spec" => %{
                          "containers" => [container]
                        }
                      }
                    },
                    "status" => %{
                      "replicas" => replicas,
                      "conditions" => [
                        %{
                          "lastUpdateTime" => DateTime.utc_now() |> DateTime.to_iso8601(),
                          "type" => "Progressing"
                        }
                      ]
                    }
                  }

                _ ->
                  build_stub_fallback(app_name, deployment_name)
              end

            false ->
              build_stub_fallback(app_name, deployment_name)
          end
        end)
      end)
    else
      []
    end
  end

  defp build_stub_fallback(app_name, deployment_name) do
    %{
      "metadata" => %{
        "name" => deployment_name,
        "annotations" => %{"app_id" => app_name}
      },
      "spec" => %{
        "template" => %{
          "spec" => %{
            "containers" => [%{"image" => "stub:latest"}]
          }
        }
      },
      "status" => %{
        "replicas" => 1,
        "conditions" => [
          %{
            "lastUpdateTime" => DateTime.utc_now() |> DateTime.to_iso8601(),
            "type" => "Progressing"
          }
        ]
      }
    }
  end

  # @docp """
  # Iterate through each deployment, and update the metadata for each app in metadata_db.
  # """

  @spec update_metadata_db(list(map()), __MODULE__.t()) :: __MODULE__.t()
  defp update_metadata_db([], state), do: state

  defp update_metadata_db([deployment | t], state) do
    app_id = deployment["metadata"]["annotations"]["app_id"]

    # discovery app is also deployed in the namespace hence skipping it
    deployment["metadata"]["name"]
    |> case do
      "discovery" ->
        update_metadata_db(t, state)

      _app ->
        # app |> IO.inspect()
        update_app_metadata(app_id, deployment, state)
        |> then(fn updated_state -> update_metadata_db(t, updated_state) end)
    end
  end

  # @docp """
  # Update an apps deployment info in state.deployment_info[app_id]
  # %{
  #   "app_id" => %{
  #     "app-a" => %{"last_updated" => "timestamp", "url" => "deployment url"}
  #   }
  #  }
  # """

  @spec update_app_metadata(String.t(), map(), __MODULE__.t()) :: __MODULE__.t()
  defp update_app_metadata(app_id, app_k8_data, state) do
    app_deployment_name = app_k8_data["metadata"]["name"]
    [container | _t] = app_k8_data["spec"]["template"]["spec"]["containers"]
    replicas = app_k8_data["status"]["replicas"]

    app_info =
      Map.get(state.deployment_info, app_id, %{})
      |> Map.put(
        app_deployment_name,
        %{
          "last_updated" => get_last_updated_time(app_k8_data["status"]),
          "url" => get_deployment_url(app_deployment_name, state.conn_ref),
          "image" => container["image"],
          "replicas" => replicas
        }
      )

    :ets.insert(Utils.metadata_db(), {app_id, app_info})
    state = put_in(state.deployment_info[app_id], app_info)
    # Logger.info(inspect(state.deployment_info))
    state
  end

  # @docp """
  # Returns the latest updated time of pod
  # """
  @spec get_last_updated_time(map()) :: any()
  defp get_last_updated_time(status) do
    status["conditions"]
    |> Enum.map(fn condition -> DateTime.from_iso8601(condition["lastUpdateTime"]) end)
    |> Enum.map(fn {:ok, date, _offset} -> date end)
    |> Enum.sort({:desc, DateTime})
    |> List.first()
  end

  @spec get_deployment_url(String.t(), any()) :: String.t()
  defp get_deployment_url(app_deployment_name, conn) do
    parts = String.split(app_deployment_name, "-")

    case parts do
      parts when length(parts) >= 2 ->
        path = List.last(parts)
        app_id = Enum.slice(parts, 0..-2//1) |> Enum.join("-")
        resolve_ingress_url(app_id, path, conn)

      _ ->
        ""
    end
  end

  defp resolve_ingress_url(app_id, path, :stub_connection) do
    ingress_path = "data/discovery/#{app_id}/ingress.yml"

    case File.exists?(ingress_path) do
      true ->
        case YamlElixir.read_from_file(ingress_path, atoms: false) do
          {:ok, ingress_data} ->
            [rule | _rules] = ingress_data["spec"]["rules"]
            "#{rule["host"]}/#{path}"

          _ ->
            "#{app_id}.example.com/#{path}"
        end

      false ->
        "#{app_id}.example.com/#{path}"
    end
  end

  defp resolve_ingress_url(app_id, path, conn) do
    Ingress.current_k8s_ingress_configuration(app_id, conn)
    |> case do
      {:ok, ingress_data} ->
        [rule | _rules] = ingress_data["spec"]["rules"]
        "#{rule["host"]}/#{path}"

      {:error, reason} ->
        IO.puts("Error on fetching ingress, due to #{inspect(reason)}")
        ""
    end
  end
end
