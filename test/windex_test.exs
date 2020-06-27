defmodule WindexTest do
  use ExUnit.Case
  doctest Windex

  test "greets the world" do
    assert Windex.hello() == :world
  end
end
