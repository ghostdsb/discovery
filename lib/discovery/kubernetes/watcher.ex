defmodule Discovery.Kubernetes.Watcher do
  @moduledoc """
  High-Speed Service Registry Watcher.
  Syncs active pod endpoints in real-time using K8s Watch API and maintains an in-memory ETS read-cache.
  """
  use GenServer
  require Logger

  alias Discovery.Utils

  @k8s_ns "discovery"
  @http_client HTTPoison

  # --- Client API ---

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Retrieves the freshest healthy connection details for a given app name in microseconds.
  """
  @spec get_allocator(String.t()) :: {:ok, map()} | {:error, :no_healthy_instances}
  def get_allocator(app_name) do
    case :ets.lookup(Utils.metadata_db(), app_name) do
      [{^app_name, details}] ->
        {:ok, details}

      _ ->
        {:error, :no_healthy_instances}
    end
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(_opts) do
    Logger.info("Initializing High-Speed Dynamic Service Watcher...")

    case Application.get_env(:discovery, :connection_method) do
      :stub ->
        Logger.info("Watcher running in passive sandbox/stub mode.")
        {:ok, %{mode: :stub}}

      :test ->
        Logger.info("Watcher running in test mode.")
        {:ok, %{mode: :test}}

      _ ->
        Logger.info("Watcher running in cluster mode (connecting to K8s Watch API)")
        send(self(), :bootstrap)
        {:ok, %{mode: :k8s, watcher_ref: nil, resource_version: "0"}}
    end
  end

  @impl true
  def handle_info(:bootstrap, state) do
    Logger.info("Bootstrapping cluster state: Fetching active pods...")

    case fetch_k8s_pods() do
      {:ok, %{"items" => items, "metadata" => %{"resourceVersion" => rv}}} ->
        process_initial_pods(items)
        watcher_ref = spawn_watch_stream(rv)
        {:noreply, %{state | watcher_ref: watcher_ref, resource_version: rv}}

      {:error, reason} ->
        Logger.error("Failed to bootstrap service directory: #{inspect(reason)}. Retrying in 5 seconds...")
        Process.send_after(self(), :bootstrap, 5_000)
        {:noreply, state}
    end
  end

  # Handle streaming watch chunks from K8s API
  @impl true
  def handle_info(%HTTPoison.AsyncStatus{code: 200}, state), do: {:noreply, state}
  @impl true
  def handle_info(%HTTPoison.AsyncHeaders{}, state), do: {:noreply, state}

  @impl true
  def handle_info(%HTTPoison.AsyncChunk{chunk: chunk_data}, state) do
    new_rv =
      chunk_data
      |> String.split("\n", trim: true)
      |> Enum.reduce(state.resource_version, fn raw_json, acc_rv ->
        case Jason.decode(raw_json) do
          {:ok, %{"type" => event_type, "object" => pod}} ->
            process_watch_event(event_type, pod)
            get_in(pod, ["metadata", "resourceVersion"]) || acc_rv

          _ ->
            acc_rv
        end
      end)

    {:noreply, %{state | resource_version: new_rv}}
  end

  # Re-bootstrap immediately if the long-lived watcher disconnected
  @impl true
  def handle_info(%HTTPoison.AsyncEnd{}, state) do
    Logger.warning("K8s Watch stream disconnected. Re-syncing registry...")
    send(self(), :bootstrap)
    {:noreply, state}
  end

  @impl true
  def handle_info(%HTTPoison.Error{reason: reason}, state) do
    Logger.error("K8s Watch stream encountered error: #{inspect(reason)}. Re-establishing connection...")
    send(self(), :bootstrap)
    {:noreply, state}
  end

  # --- Helper Pipeline Logic ---

  defp fetch_k8s_pods do
    url = k8s_api_base_url() <> "/api/v1/namespaces/#{@k8s_ns}/pods"
    headers = k8s_auth_headers()
    opts = k8s_request_options()

    case @http_client.get(url, headers, opts) do
      {:ok, %{status_code: 200, body: body}} -> Jason.decode(body)
      error -> {:error, error}
    end
  end

  defp spawn_watch_stream(resource_version) do
    url = k8s_api_base_url() <> "/api/v1/namespaces/#{@k8s_ns}/pods?watch=true&resourceVersion=#{resource_version}"
    headers = k8s_auth_headers()
    opts = k8s_request_options() ++ [stream_to: self(), recv_timeout: :infinity]

    {:ok, ref} = @http_client.get(url, headers, opts)
    ref
  end

  defp k8s_request_options do
    ca_cert_path = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"

    ssl_opts =
      if File.exists?(ca_cert_path) do
        [cacertfile: ca_cert_path, verify: :verify_peer]
      else
        [verify: :verify_none]
      end

    [ssl: ssl_opts]
  end

  defp process_initial_pods(pods) do
    :ets.delete_all_objects(Utils.metadata_db())

    pods
    |> Enum.filter(&is_active_and_healthy?/1)
    |> Enum.group_by(fn pod -> pod["metadata"]["labels"]["app"] end)
    |> Enum.each(fn {app_name, app_pods} ->
      freshest_pod =
        app_pods
        |> Enum.sort_by(fn pod -> parse_timestamp(pod["metadata"]["creationTimestamp"]) end, {:desc, DateTime})
        |> List.first()

      cache_pod(app_name, freshest_pod)
    end)
  end

  defp process_watch_event("DELETED", pod) do
    app_name = pod["metadata"]["labels"]["app"]
    pod_name = pod["metadata"]["name"]
    Logger.info("Watch Event [DELETED]: Tearing down routes for pod #{pod_name}")

    case :ets.lookup(Utils.metadata_db(), app_name) do
      [{^app_name, %{pod_name: ^pod_name}}] ->
        :ets.delete(Utils.metadata_db(), app_name)

      _ ->
        :ok
    end
  end

  defp process_watch_event(event_type, pod) when event_type in ["ADDED", "MODIFIED"] do
    app_name = pod["metadata"]["labels"]["app"]

    if pod["metadata"]["deletionTimestamp"] != nil do
      pod_name = pod["metadata"]["name"]
      Logger.info("Watch Event [DRAINING]: Pod #{pod_name} entered terminating state. Evicting from active routing pool.")

      case :ets.lookup(Utils.metadata_db(), app_name) do
        [{^app_name, %{pod_name: ^pod_name}}] ->
          :ets.delete(Utils.metadata_db(), app_name)

        _ ->
          :ok
      end
    else
      if is_active_and_healthy?(pod) do
        case :ets.lookup(Utils.metadata_db(), app_name) do
          [{^app_name, cached}] ->
            new_ts = parse_timestamp(pod["metadata"]["creationTimestamp"])

            if DateTime.compare(new_ts, cached.created_at) == :gt do
              Logger.info("Watch Event [UPGRADE]: Promoting newer pod #{pod["metadata"]["name"]} to active client routes.")
              cache_pod(app_name, pod)
            end

          _ ->
            Logger.info("Watch Event [INITIAL]: Registering active route for app #{app_name} on pod #{pod["metadata"]["name"]}")
            cache_pod(app_name, pod)
        end
      end
    end
  end

  # --- Parsing Utility Guards ---

  defp is_active_and_healthy?(pod) do
    is_nil(pod["metadata"]["deletionTimestamp"]) and
      pod["status"]["phase"] == "Running" and
      pod_ready_condition_true?(pod)
  end

  defp pod_ready_condition_true?(pod) do
    conditions = get_in(pod, ["status", "conditions"]) || []

    Enum.any?(conditions, fn cond ->
      cond["type"] == "Ready" and cond["status"] == "True"
    end)
  end

  defp cache_pod(app_name, pod) do
    ip = pod["status"]["podIP"] || "127.0.0.1"
    port = get_in(pod, ["spec", "containers"]) |> List.first() |> get_in(["ports"]) |> List.first() |> Map.get("containerPort") || 4000
    created_at = parse_timestamp(pod["metadata"]["creationTimestamp"])
    version = pod["metadata"]["resourceVersion"] || "0"
    ingress_url = get_ingress_url_fallback(app_name, pod["metadata"]["name"])
    pod_name = pod["metadata"]["name"]

    :ets.insert(Utils.metadata_db(), {app_name, %{
      pod_name: pod_name,
      ip: ip,
      port: port,
      created_at: created_at,
      version: version,
      url: ingress_url,
      image: get_in(pod, ["spec", "containers"]) |> List.first() |> Map.get("image") || "unknown",
      replicas: 1,
      last_updated: created_at
    }})
  end

  defp get_ingress_url_fallback(app_name, pod_name) do
    parts = String.split(pod_name, "-")
    path = List.last(parts)
    "#{app_name}.example.com/#{path}"
  end

  defp parse_timestamp(nil), do: DateTime.utc_now()
  defp parse_timestamp(iso_str) do
    case DateTime.from_iso8601(iso_str) do
      {:ok, dt, _} -> dt
      _ -> DateTime.utc_now()
    end
  end



  defp k8s_api_base_url do
    System.get_env("KUBERNETES_SERVICE_HOST")
    |> case do
      nil -> "http://localhost:8001"
      host -> "https://#{host}:#{System.get_env("KUBERNETES_SERVICE_PORT_HTTPS")}"
    end
  end

  defp k8s_auth_headers do
    token_path = "/var/run/secrets/kubernetes.io/serviceaccount/token"

    if File.exists?(token_path) do
      token = File.read!(token_path) |> String.trim()
      [{"Authorization", "Bearer #{token}"}, {"Accept", "application/json"}]
    else
      [{"Accept", "application/json"}]
    end
  end
end
