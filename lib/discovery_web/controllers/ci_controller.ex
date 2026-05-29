defmodule DiscoveryWeb.CiController do
  use DiscoveryWeb, :controller
  alias Discovery.Orchestrator.Pipeline

  @deploy_params %{
    app_name: [type: :string, required: true],
    image: [type: :string, required: true],
    environment: [type: :string, required: true],
    config_ref: [type: :map, required: true],
    idempotency_key: [type: :string, required: false]
  }

  @spec deploy(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def deploy(conn, params) do
    with {:ok, params} <- Tarams.cast(params, @deploy_params),
         {:ok, result} <-
           Pipeline.ci_deploy(
             params.app_name,
             params.image,
             params.environment,
             params.config_ref,
             params[:idempotency_key]
           ) do
      json(conn, %{success: true, data: result})
    else
      {:error, reason} ->
        conn |> put_status(400) |> json(%{success: false, error: reason})
    end
  end

  @status_params %{
    deployment_name: [type: :string, required: true]
  }

  @spec status(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def status(conn, params) do
    with {:ok, params} <- Tarams.cast(params, @status_params),
         {:ok, result} <- Pipeline.ci_status(params.deployment_name) do
      json(conn, %{success: true, data: result})
    else
      {:error, reason} ->
        conn |> put_status(400) |> json(%{success: false, error: reason})
    end
  end
end
