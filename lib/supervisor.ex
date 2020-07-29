defmodule Windex.Supervisor do
  use Supervisor
  require DynamicSupervisor
  require Logger

  def init(_) do
    children = [{DynamicSupervisor, name: Windex.Sessions, strategy: :one_for_one}]
    Supervisor.init(children, strategy: :one_for_one)
  end

  def start(_, _) do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end
end
