# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :athel,
  ecto_repos: [Athel.Repo]

# Configures the endpoint
config :athel, AthelWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Kq4pSxruZ4nUA7dTY8Ydsl9u8zvzqqnDCi18oMMWQfArkNW4jWfUFX0Mu6UmW4DX",
  render_errors: [view: AthelWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Athel.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $metadata[$module] - $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
