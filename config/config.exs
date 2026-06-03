# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Configures the endpoint
config :discovery, DiscoveryWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "g1PHdlhOK+iqbT8lX0iVWGra5tUPixVmSD752nswvRja0x1NLeqGEeSJdOR3/UVS",
  render_errors: [view: DiscoveryWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Discovery.PubSub,
  live_view: [signing_salt: "0tLW2WSY"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :discovery,
  # Connection method to use for communicating with Kubernetes:
  #   - :stub            => Local Sandbox Mode (Offline). Mock connection requiring zero Kubernetes
  #                         infrastructure. Loads and writes files to the local "data/discovery/" folder.
  #   - :service_account => In-Cluster Mode. Uses standard service account tokens inside a live K8s pod.
  #   - :kube_config     => Local Cluster Mode. Loads cluster context from the local "~/.kube/config" file.
  connection_method: :service_account,
  api_token: System.get_env("API_TOKEN") || "discovery-secret-token",
  base_url: System.get_env("BASE_URL") || "http://localhost:4000",
  watch_namespace: System.get_env("WATCH_NAMESPACE") || "all"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
