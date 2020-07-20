defmodule Windex do
  def spawn_server(opts \\ [run: :observer]) do
    {:ok, pid} = DynamicSupervisor.start_child(Windex.Sessions, {Windex.VNC, opts})
    {GenServer.call(pid, :get_port), GenServer.call(pid, :get_password)}
  end

  def available_opts do
    [
      [run: "xterm"],
      [run: :observer],
      [display: ":1"],
      [display: ":1", viewonly: true],
    ]
  end
end
