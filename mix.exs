defmodule Athel.Mixfile do
  use Mix.Project

  def project do
    [app: :athel,
     version: "0.1.0",
     elixir: "~> 1.7",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix, :gettext] ++ Mix.compilers,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     aliases: aliases(),
     deps: deps()]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [mod: {Athel.Application, []},
     extra_applications: [:logger, :runtime_tools]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  defp deps do
    [
      # added by phoenix
      {:phoenix, "~> 1.3.0"},
      {:phoenix_pubsub, "~> 1.0"},
      {:phoenix_ecto, "~> 3.3.0"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 2.12.0"},
      {:phoenix_live_reload, "~> 1.0", only: :dev},
      {:gettext, "~> 0.16.0"},
      {:cowboy, "~> 1.0"},
      # added by hand
      {:timex, "~> 3.3"},
      {:timex_ecto, "~> 3.3"},
      {:cloak, "~> 0.7.0"},
      {:ex_multihash, github: "ruhlio/ex_multihash"},
      {:emagic, github: "JasonZhu/erlang_magic"},
      {:credo, "~> 0.10", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    ["ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
     "ecto.reset": ["ecto.drop", "ecto.setup"],
     "test": ["ecto.create --quiet", "ecto.migrate", "test"]]
  end
end
