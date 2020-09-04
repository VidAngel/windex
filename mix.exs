defmodule Windex.MixProject do
  use Mix.Project

  def project do
    [
      app: :windex,
      version: "0.3.6",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: [
        compile: ["compile", &compile_observer/1]
      ],
    ]
  end

  defp compile_observer(_) do
    :elixir_compiler.file_to_path("#{:code.priv_dir(:windex)}/observer.ex", "#{:code.priv_dir(:windex)}", fn _, _ -> nil end)
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
      {:erlexec, "~> 1.17.5"}
    ]
  end

end
