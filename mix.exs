defmodule Windex.MixProject do
  use Mix.Project

  def project do
    [
      app: :windex,
      version: "0.2.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Windex.Supervisor, []},
      extra_applications: [:logger, :erlexec, :inets]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:erlexec, "~> 1.17.0"},
      {:jason, "~> 1.2"},
    ]
  end
end
