defmodule Windex.MixProject do
  use Mix.Project

  def project do
    [
      app: :windex,
      version: "0.3.7",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Windex.Supervisor, []},
      extra_applications: [:logger, :erlexec, :inets, :crypto, :wx, :observer, :runtime_tools],
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:pc, "~> 1.11.0", override: true},
      {:erlexec, "~> 1.17.5"}
    ]
  end

end
