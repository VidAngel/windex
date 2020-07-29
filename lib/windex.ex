defmodule Windex do
  def spawn_server(opts \\ [run: :observer]) do
    {:ok, pid} = DynamicSupervisor.start_child(Windex.Sessions, {Windex.VNC, opts})
    {GenServer.call(pid, :get_port), GenServer.call(pid, :get_password)}
  end

  def get_commands do
    mod = Application.get_env(:windex, :command_module, Windex.CommandList.Default)
    apply(mod, :commands, [])
  end
end
