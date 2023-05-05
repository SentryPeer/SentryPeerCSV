defmodule SentrypeerCsv.MixProject do
  use Mix.Project

  def project do
    [
      app: :sentrypeer_csv,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_csv, "~> 1.1"},
      {:httpoison, "~> 2.0"},
      {:jason, "~> 1.3"}
    ]
  end
end
