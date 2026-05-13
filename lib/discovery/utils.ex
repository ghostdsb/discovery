defmodule Discovery.Utils do
  @moduledoc """
  Common utility functions across contexts
  """
  @spec get_uid :: String.t()
  def get_uid do
    UUID.uuid1()
    |> String.split("-")
    |> List.first()
  end

  @doc """
  Returns the MetadataDB name.
  """
  @spec metadata_db() :: atom()
  def metadata_db do
    :metadatadb
  end

  @doc """
  Returns the BridgeDB name.
  """
  @spec bridge_db() :: atom()
  def bridge_db do
    :bridgedb
  end

  @doc """
  Returns the IdempotencyDB name.
  """
  @spec idempotency_db() :: atom()
  def idempotency_db do
    :idempotencydb
  end

  @spec puts_success(any) :: :ok
  def puts_success(term) do
    IO.puts(IO.ANSI.format([:green_background, :black, inspect(term)]))
  end

  @spec puts_warn(any) :: :ok
  def puts_warn(term) do
    IO.puts(IO.ANSI.format([:yellow_background, :black, inspect(term)]))
  end

  @spec puts_error(any) :: :ok
  def puts_error(term) do
    IO.puts(IO.ANSI.format([:red_background, :black, inspect(term)]))
  end

  @doc """
  Saves a map to a YAML file.
  """
  @spec to_yml(map, String.t()) :: :ok | {:error, any()}
  def to_yml(map, location) do
    yml = Yamlix.dump(map, false)

    with {:ok, io} <- File.open(location, [:write, :utf8]),
         :ok <- IO.write(io, yml) do
      File.close(io)
    end
  end
end
