defmodule SentrypeerCsv.MixProject do
  use Mix.Project

  def project do
    [
      app: :sentrypeer_csv,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "SentryPeerCSV",
      source_url: "https://github.com/SentryPeer/SentryPeerCSV",
      homepage_url: "https://sentypeer.com"
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

  defp description() do
    "Parse a CSV file of Call Data Records (CDRs) and check SentryPeerHQ API (https://github.com/SentryPeer/SentryPeerHQ) to find a match."
  end

  defp package() do
    [
      files: ~w(lib .formatter.exs mix.exs CHANGELOG.md CONTRIBUTING.md
                      COPYRIGHT LICENSE README.md SECURITY.md),
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/SentryPeer/SentryPeerCSV",
        "SentryPeerHQ" => "https://github.com/SentryPeer/SentryPeerHQ",
        "SentryPeer" => "https://sentypeer.com"
      }
    ]
  end
end
