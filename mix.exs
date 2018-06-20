defmodule Fluent.Mixfile do
  use Mix.Project

  def project() do
    [
      app: :fluent,
      version: "0.1.0",
      elixirc_options: elixirc_options(),
      deps: deps()
    ]
  end

  def application() do
    []
  end

  def elixirc_options() do
    [all_warnings: true, warnings_as_errors: true]
  end

  defp deps() do
    [{:msgpack, "~> 0.7.0"}]
  end
end
