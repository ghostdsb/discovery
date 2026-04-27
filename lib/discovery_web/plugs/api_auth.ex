defmodule DiscoveryWeb.Plugs.ApiAuth do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    api_token = Application.get_env(:discovery, :api_token)
    header_token = get_req_header(conn, "x-api-token") |> List.first()

    if header_token == api_token do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "unauthorized"})
      |> halt()
    end
  end
end
