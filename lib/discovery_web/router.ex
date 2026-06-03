defmodule DiscoveryWeb.Router do
  use DiscoveryWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {DiscoveryWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug CORSPlug, origin: "*"
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug CORSPlug, origin: "*"
  end

  def cors_origins do
    Application.get_env(:discovery, :cors_origins, ["*"])
  end

  scope "/", DiscoveryWeb do
    pipe_through :browser

    live "/", PageLive, :index
  end

  get "/ping", DiscoveryWeb.BaseController, :ping, log: false

  # High-speed API endpoints
  scope "/api", DiscoveryWeb do
    pipe_through :api

    get "/endpoint", EndpointController, :get_endpoint
    get "/apps", BaseController, :list_app
    post "/app", BaseController, :create_app
    delete "/app", BaseController, :delete_app
    get "/watcher/status", BaseController, :check_watcher_status
  end

  # Enables LiveDashboard only for development
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: DiscoveryWeb.Telemetry
    end
  end
end
