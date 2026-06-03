defmodule DiscoveryWeb.BaseController do
  use DiscoveryWeb, :controller

  alias Discovery.Dashboard.Queries, as: DashboardQueries

  def ping(conn, _params) do
    json(conn, "pong from discovery: v#{Application.spec(:discovery, :vsn)}")
  end

  @spec list_app(Plug.Conn.t(), any) :: Plug.Conn.t()
  def list_app(conn, _params) do
    app_list = DashboardQueries.get_apps()
    json(conn, %{apps: app_list})
  end

  @create_app_params %{
    app_name: [type: :string, required: true]
  }
  @spec create_app(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create_app(conn, params) do
    with {:ok, params} <- Tarams.cast(params, @create_app_params),
         {:ok, :app_inserted} <- DashboardQueries.create_app(params.app_name) do
      json(conn, params)
    else
      {:error, reason} -> json(put_status(conn, 400), reason)
    end
  end

  @delete_app_params %{
    app_name: [type: :string, required: true]
  }
  @spec delete_app(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete_app(conn, params) do
    with {:ok, params} <- Tarams.cast(params, @delete_app_params),
         {:ok, _} <- DashboardQueries.delete_app(params.app_name) do
      json(conn, params)
    else
      {:error, _} ->
        json(put_status(conn, 400), "error")
    end
  end

  @check_watcher_status_params %{
    app_name: [type: :string, required: true]
  }
  @spec check_watcher_status(Plug.Conn.t(), map) :: Plug.Conn.t()
  def check_watcher_status(conn, params) do
    with {:ok, params} <- Tarams.cast(params, @check_watcher_status_params) do
      app_name = params.app_name
      tracked = :ets.member(Discovery.Utils.bridge_db(), app_name)

      case :ets.lookup(Discovery.Utils.metadata_db(), app_name) do
        [{^app_name, details}] ->
          json(conn, %{
            app_name: app_name,
            tracked: tracked,
            active: true,
            details: %{
              ip: details.ip,
              port: details.port,
              created_at: details.created_at,
              version: details.version,
              url: details.url,
              image: details.image,
              replicas: details.replicas,
              last_updated: details.last_updated
            }
          })

        _ ->
          json(conn, %{
            app_name: app_name,
            tracked: tracked,
            active: false,
            details: nil
          })
      end
    else
      {:error, reason} -> json(put_status(conn, 400), reason)
    end
  end
end
