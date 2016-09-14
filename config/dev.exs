use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
config :athel, Athel.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [node: ["node_modules/brunch/bin/brunch", "watch",
                    cd: Path.expand("../", __DIR__)]]


# Watch static and templates for browser reloading.
config :athel, Athel.Endpoint,
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{priv/gettext/.*(po)$},
      ~r{web/views/.*(ex)$},
      ~r{web/templates/.*(eex)$}
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Configure your database
config :athel, Athel.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "athel_dev",
  hostname: "localhost",
  pool_size: 10

config :athel, Athel.Nntp,
  port: 8119,
  pool_size: 10,
  timeout: 5_000,
  keyfile: Path.expand("../priv/testing.key", __DIR__),
  certfile: Path.expand("../priv/testing.crt", __DIR__),
  max_request_size: 75_000_000,
  max_attachment_size: 20_000_000,
  max_attachment_count: 3,
