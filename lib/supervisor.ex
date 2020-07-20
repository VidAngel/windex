defmodule Windex.Supervisor do
  use Supervisor
  require DynamicSupervisor
  require Logger

  def init(_) do
    children = [
      {DynamicSupervisor, name: Windex.Sessions, strategy: :one_for_one},
      Windex.HTTP,
      {Registry, keys: :unique, name: Windex.OptionSets},
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end

  def start(_, _) do
    result = {:ok, _} = Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
    Logger.info(http_info())
    result
  end

  defp http_info do
    Windex.Supervisor
    |> Supervisor.which_children
    |> Enum.map(&Tuple.to_list/1)
    |> Enum.find(fn x -> Enum.at(x, 0) == Windex.HTTP end)
    |> http_info()
  end

  defp http_info(nil), do: "No HTTP server running."
  defp http_info([_, pid | _]) do
    info = :httpd.info(pid)
    addr = info[:bind_address] |> format_ip
    "HTTP server running on http://#{addr}:#{info[:port]}"
  end

  defp format_ip(:any), do: "0.0.0.0"
  defp format_ip(x) when is_tuple(x), do: x |> Tuple.to_list |> Enum.join(".")
  defp format_ip(x), do: inspect x

end
