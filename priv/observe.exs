defmodule Windex.Observer do
  require Record

  Record.defrecordp(:wx, Record.extract(:wx, from_lib: "wx/include/wx.hrl"))
  Record.defrecordp(:wxClose, Record.extract(:wxClose, from_lib: "wx/include/wx.hrl"))
  Record.defrecordp(:wxCommand, Record.extract(:wxCommand, from_lib: "wx/include/wx.hrl"))
  Record.defrecordp(:wx_env, Record.extract(:wx_env, from_lib: "wx/src/wxe.hrl"))

  def run(node) when is_bitstring(node), do: node |> String.to_atom |> run
  def run(node) do
    :observer.start
    env = wx_env(sv: Process.whereis(:observer), port: :observer_wx.get_attrib(:opengl_port))
    :wx.set_env(env)
    menu_idx = :wxMenuBar.findMenu(:observer_wx.get_menubar, "Nodes")
    label_id = :wxMenuBar.getMenu(:observer_wx.get_menubar, menu_idx)
      |> :wxMenu.getMenuItems
      |> Enum.find(fn item -> IO.inspect(:wxMenuItem.getLabel(item)) |> List.to_atom == node end)
      |> :wxMenuItem.getId
    send(:observer, wx(id: label_id, event: wxCommand(type: :command_menu_selected)))
  end
end

[node | _ ] = System.argv
Windex.Observer.run(node)
