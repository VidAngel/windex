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

    {:ok, display} = spawn_xserver!(xserver)
    {:ok, _pid, _ospid} = spawn_program!(program, args, display)
    {:ok, password} = spawn_vnc!(display, port, viewonly?)

    {:ok, {password, port}}
  end

  defp spawn_program!(nil, _, _), do: {:ok, nil}

  defp spawn_program!(:observer, _, display) do
    :exec.run_link("xterm", args: [], env: [{"DISPLAY", display}], stdout: self(), stderr: self())
  end

  defp spawn_program!(program, args, display) do
    :exec.run_link("#{program} #{Enum.join(args, " ")}" |> String.to_charlist, env: [{"DISPLAY", display}], stdout: self(), stderr: self())
  end

  # assume it's an already running xserver
  def spawn_xserver!(xserver) when is_bitstring(xserver), do: {:ok, xserver}
  def spawn_xserver!(nil) do
    # TODO: random display
    {:ok, _pid, _ospid} = :exec.run_link("Xvfb -displayfd 1", stdout: self(), stderr: self())
  end

  def start_link(opts) when is_list(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def handle_call(:get_password, _remote, {password, port}) do
    {:reply, password, {nil, port}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :port, _object, _reason}, _state) do
    {:stop, :normal}
  end

  @impl true
  def handle_info(x, state) do
    IO.inspect x
    {:noreply, state}
  end

  defp spawn_vnc!(display, port, viewonly) do
    {tmpfile, 0} = System.cmd("mktemp", [])
    tmpfile = tmpfile |> String.trim
    password = password!()
    :os.cmd("echo #{password} | vncpasswd > #{tmpfile}" |> String.to_charlist)
    args = "-displayfd #{display} -rfbport #{port} -passwdfile #{tmpfile}"

    case viewonly do
      true ->
        password = password!()
        {:ok, _, _} = :exec.run_link("x11vnc #{args} -viewpasswd #{password}" |> String.to_charlist, [])
        {:ok, password}
      false ->
        {:ok, _, _} = :exec.run_link("x11vnc #{args}" |> String.to_charlist, [])
        {:ok, password}
    end
  end

  defp password! do
    :crypto.strong_rand_bytes(64) |> Base.encode16(case: :lower)
  end

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
