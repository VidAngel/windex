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

defmodule Windex.CommandList do
  defmacro __using__(_opts) do
    quote do
      def commands, do: [ [run: :observer], [run: "xterm"], ]
      defoverridable commands: 0
    end
  end
end
defmodule Windex.CommandList.Default, do: use Windex.CommandList
