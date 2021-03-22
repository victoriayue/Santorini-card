defmodule SCARDTest do
  use ExUnit.Case
  doctest SCARD.CLI

  test "greets the world" do
    SCARD.CLI.main()
  end
end
