defmodule SCARDTest do
  use ExUnit.Case
  doctest SCARD.CLI

  @tag timeout: :infinity 
  test "greets the world" do

    SCARD.CLI.main()
  end
end
