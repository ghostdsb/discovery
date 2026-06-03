# In this file, we load production configuration and secrets
# from environment variables. You can also hardcode secrets,
# although such is generally not recommended and you have to
# remember to add this file to your .gitignore.
import Config

connection_method =
  System.get_env("CONNECTION_METHOD")
  |> case do
    "stub" -> :stub
    "service_account" -> :service_account
    "kube_config" -> :kube_config
    _ -> nil
  end

if connection_method do
  config :discovery, connection_method: connection_method
end

if System.get_env("API_TOKEN") do
  config :discovery, api_token: System.get_env("API_TOKEN")
end

if System.get_env("BASE_URL") do
  config :discovery, base_url: System.get_env("BASE_URL")
end

if System.get_env("PORT") do
  config :discovery, DiscoveryWeb.Endpoint,
    http: [port: String.to_integer(System.get_env("PORT"))],
    server: true
end

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  config :discovery, DiscoveryWeb.Endpoint,
    http: [
      port: String.to_integer(System.get_env("DISCOVERY_PORT")),
      transport_options: [socket_opts: [:inet6]]
    ],
    secret_key_base: secret_key_base

  # ## Using releases (Elixir v1.9+)
  #
  # If you are doing OTP releases, you need to instruct Phoenix
  # to start each relevant endpoint:
  #
  config :discovery, DiscoveryWeb.Endpoint, server: true
  #
  # Then you can assemble a release by calling `mix release`.
  # See `mix help release` for more information.
  api_token = System.get_env("API_TOKEN") || "discovery-secret-token"
  base_url = System.get_env("BASE_URL") || "https://discovery.example.com"

  config :discovery,
    api_token: api_token,
    base_url: base_url
end
