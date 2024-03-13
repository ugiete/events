defmodule EasyWANTest do
  use ExUnit.Case
  doctest EasyWAN

  test "greets the world" do
    assert EasyWAN.hello() == :world
  end
end
