defmodule Windex.VNC do
  alias Application, as: App
  require GenServer
  @behaviour GenServer

  @impl true
  def init(opts) when is_list(opts) do
    port      = Keyword.get(opts, :port, available_port())
    program   = Keyword.get(opts, :run)
    args      = Keyword.get(opts, :args, [])
    xserver   = Keyword.get(opts, :xserver)
    viewonly? = Keyword.get(opts, :viewonly, false)

    linked_procs = []

    if not xserver do
      {:ok, {xserver, proc}} = spawn_xserver!
      linked_procs = linked_procs ++ [proc]
    end

    if program do
      {:ok, proc} = spawn_program!(program, xserver, args)
      linked_procs = linked_procs ++ [proc]
    end

    {:ok, {password, proc}} = spawn_vnc!(xserver, port)
    linked_procs = linked_procs ++ [proc]
    {:ok, {password, linked_procs}}
  end

  def start_link(opts) when is_list(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def handle_call(:get_password, {password, linked_procs}) do
    {:reply, password, {nil, linked_procs}}
  end

  def handle_info({:DOWN, _ref, :port, _object, _reason}, {_, linked_procs}) do
    linked_procs |> Enum.map(&Port.close/1)
    {:stop, :normal}
  end

  defp spawn_program!(path, display, args) do
    {:ok, port} = Port.open({:spawn_executable, path}, [env: [DISPLAY: display], args: args])
    Port.monitor(port)
  end

  defp spawn_xserver!, do: nil
  defp spawn_vnc!(display, port), do: nil

  defp port_range, do: (start_port()..end_port())

  defp available_port do
    used_ports = :os.cmd('ss -Htan | awk \'{print $4}\' | cut -d\':\' -f2')|> List.to_string |> String.split |> Enum.map(&String.to_integer/1)
    port = port_range() |> Enum.random
    case port in used_ports do
      false -> port
      true -> available_port()
    end
  end

  defp start_port do
    port_file = "/proc/sys/net/ipv4/ip_local_port_range"
    case App.get_env(:windex, :start_port, File.read(port_file)) do
      {:error, :enoent} -> 49152
      {:ok, x} -> x |> String.split |> List.first |> String.to_integer
      x -> x
    end
  end

  defp end_port do
    port_file = "/proc/sys/net/ipv4/ip_local_port_range"
    case App.get_env(:windex, :end_port, File.read(port_file)) do
      {:error, :enoent} -> 65535
      {:ok, x} -> x |> String.split |> List.last |> String.to_integer
      x -> x
    end
  end

end
