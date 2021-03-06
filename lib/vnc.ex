defmodule Windex.VNC do
  use GenServer, restart: :temporary
  alias Application, as: App

  require GenServer
  require Logger

  @impl true
  def init(opts) when is_list(opts) do
    port      = Keyword.get(opts, :port, available_port())
    program   = Keyword.get(opts, :run)
    args      = Keyword.get(opts, :args, (if program == :observer, do: [Node.self(), Node.get_cookie()], else: []))
    xserver   = Keyword.get(opts, :display)
    viewonly? = Keyword.get(opts, :viewonly, false)
    password  = password(Keyword.get(opts, :password))

    Logger.debug("PID -> #{inspect self()}")

    spawn_xserver!(xserver)

    receive do
      {:stdout, _, x}  ->
        display = ":" <> String.trim(x)
        Logger.debug("Display -> #{display}")
        decorate!(display, !!xserver)
        spawn_program!(program, args, display)
        password = spawn_vnc!(display, port, viewonly?, password)
        {:ok, {password, port}}
    after
      5_000 -> {:stop, "X server didn't seem to start correctly."}
    end
  end

  defp decorate!(_preexisting_server, true) do
    Logger.debug "Pre-existing server, not decorating"
    nil
  end
  defp decorate!(xserver, _) do
    spawn(fn ->
      Process.sleep(1000)
      System.cmd("xsetroot", ["-solid", "#34434b", "-display", xserver])
      System.cmd("twm", ["-f", "#{:code.priv_dir(:windex)}/twm.rc", "-display", xserver])
    end)
  end

  defp spawn_program!(nil, _, _) do
    Logger.debug "No requested application"
    {:ok, nil}
  end

  defp spawn_program!(:observer, [node, cookie], display) do
    nodename = "#{observer_name()}@127.0.0.1"
    observer_path = :code.where_is_file('Elixir.Windex.Observer.beam') |> Path.dirname
    cmd = "#{elixir_bin()} #{boot_vars()} -pa #{observer_path} --boot #{boot_file()} --name #{nodename} --hidden --cookie #{cookie} --erl \"-noinput -env DISPLAY #{display}\" -e \"Windex.Observer.run(:\\\"#{node}\\\")\""
    Logger.info "Starting erlang observer"
    {:ok, pid, _} = :exec.run_link(cmd, [{:stdout, self()}, {:stderr, self()}, :monitor])
    Process.monitor(pid)
  end

  defp spawn_program!(program, args, display) do
    cmd = "#{program} #{Enum.join(args, " ")}"
    Logger.info "Launching #{cmd}"
    {:ok, pid, _} = :exec.run_link(cmd, [{:env, [{"DISPLAY", display}]}, {:stdout, self()}, {:stderr, self()}, :monitor])
    Process.monitor(pid)
  end

  defp elixir_bin,      do: elixir_bin(release_dir())
  defp elixir_bin(nil), do: "elixir"
  defp elixir_bin(path),do: path <> "/elixir"
  defp boot_file,       do: boot_file(release_dir())
  defp boot_file(nil),  do: "$ROOT/start"
  defp boot_file(dir),  do: dir <> "/start_clean"
  defp release_version, do: System.get_env("RELEASE_VSN", nil)
  defp release_root,    do: System.get_env("RELEASE_ROOT", nil)
  defp release_dir,     do: release_dir(release_root(), release_version())
  defp release_dir(root, vsn) when is_bitstring(root) and is_bitstring(vsn), do: (root <> "/releases/") <> vsn
  defp release_dir(_, _), do: nil
  defp boot_vars do
    if release_root() do
      "--boot-var RELEASE_LIB \"#{release_root()}\"/lib"
    else
      ""
    end
  end


  defp observer_name(), do: "windex-#{password()}"

  # assume it's an already running xserver
  defp spawn_xserver!(xserver) when is_bitstring(xserver), do: {:ok, send(self(), {:stdout, nil, Regex.replace(~r/^:/,xserver,"")})}
  defp spawn_xserver!(nil) do
    {:ok, pid, _} = :exec.run_link("Xvfb -displayfd 1", [{:stdout, self()}, {:stderr, self()}, :monitor])
    Process.monitor(pid)
  end

  def start_link(opts) when is_list(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def handle_call(:get_password, _remote, {password, port}) do
    {:reply, password, {nil, port}}
  end

  @impl true
  def handle_call(:get_port, _remote, {password, port}) do
    {:reply, port, {password, port}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    Logger.info "Closing Windex instance"
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:stderr, _, out}, state) do
    Logger.debug("STDERR\t#{inspect out}")
    {:noreply, state}
  end

  @impl true
  def handle_info({:stdout, _, out}, state) do
    Logger.debug("STDOUT\t#{inspect out}")
    {:noreply, state}
  end

  def handle_info(what, state) do
    Logger.debug(inspect what)
    {:noreply, state}
  end

  defp spawn_vnc!(display, port, viewonly?, password) do
    # the "rm:" prefix means x11vnc will delete the file after reading
    # see -passwdfile flag documentation for x11vnc
    # https://linux.die.net/man/1/x11vnc
    {tmpfile, 0} = System.cmd("mktemp", ["windex.XXXXXXXXXX", "--tmpdir"])
    tmpfile = tmpfile |> String.trim
    File.write!(tmpfile, "#{viewonly? && password() || password}\n")
    timeout = Application.get_env(:windex, :connection_timeout_seconds, 10)
    cmd = "x11vnc -timeout #{timeout} -norc -display #{display} -rfbport #{port} -passwdfile rm:#{tmpfile}" |> String.to_charlist
    Logger.debug cmd

    case viewonly?  do
      true ->
        File.write!(tmpfile, "__BEGIN_VIEWONLY__\n#{password}\n", [:append])
        {:ok, pid, _} = :exec.run_link(cmd, [{:stdout, self()}, {:stderr, self()}, :monitor])
        Process.monitor(pid)
        password
      false ->
        {:ok, pid, _} = :exec.run_link(cmd, [{:stdout, self()}, {:stderr, self()}, :link])
        Process.monitor(pid)
        password
    end
  end

  defp password(x) when is_binary(x), do: String.slice(x, 0..7)
  defp password(x) when is_list(x),   do: x |> List.to_string |> password
  defp password(_), do: password()

  defp password() do
    :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower) |> String.slice(0..7)
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
