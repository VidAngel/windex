defmodule Windex.VNC do
  alias Application, as: App
  require GenServer
  @behaviour GenServer

  @impl true
  def init(opts) when is_list(opts) do
    port      = Keyword.get(opts, :port, available_port())
    program   = Keyword.get(opts, :run)
    args      = Keyword.get(opts, :args, [])
    xserver   = Keyword.get(opts, :display)
    viewonly? = Keyword.get(opts, :viewonly, false)

    linked_procs = []

    {:ok, display} = spawn_xserver!(xserver)
    pid = spawn_program!(program, args, display)
    {:ok, password} = spawn_vnc!(display, port)

    {:ok, nil}
  end

  defp spawn_program!(nil, _, _), do: {:ok, nil}

  defp spawn_program!(:observer, _, display) do
    spawn_link(fn -> MuonTrap.cmd("xterm", [], env: [{"DISPLAY", display}]) end)
  end

  defp spawn_program!(program, args, display) do
    spawn_link(fn -> MuonTrap.cmd(program, args, env: [{"DISPLAY", display}]) end)
  end

  # assume it's an already running xserver
  def spawn_xserver!(xserver) when is_bitstring(xserver), do: {:ok, xserver}
  def spawn_xserver!(nil) do
    spawn(fn ->
      MuonTrap.cmd("Xvfb", ["-displayfd", "1"], into: IO.stream(:stdio, :line))
    end)
  end

  def start_link(opts) when is_list(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def handle_call(:get_password, {password, linked_procs}) do
    {:reply, password, {nil, linked_procs}}
  end

  def handle_info(x, s) do
    IO.inspect x
    {:noreply, s}
  end

  def handle_info({:DOWN, _ref, :port, _object, _reason}, {_, linked_procs}) do
    linked_procs |> Enum.map(&Port.close/1)
    {:stop, :normal}
  end

  defp spawn_vnc!(display, port), do: {:ok, nil}

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
