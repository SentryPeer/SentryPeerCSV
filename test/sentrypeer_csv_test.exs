defmodule SentrypeerCsvTest do
  use ExUnit.Case
  doctest SentrypeerCsv

  test "explains that you need to set client_id and client_secret ENV var" do
    assert SentrypeerCsv.parse_csv("does_not_exist.csv") =~ "client_id and client_secret"
  end
end
