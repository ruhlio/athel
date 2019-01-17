use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
config :athel, AthelWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [node: ["node_modules/brunch/bin/brunch", "watch",
                    cd: Path.expand("../assets", __DIR__)]]


# Watch static and templates for browser reloading.
config :athel, AthelWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{priv/gettext/.*(po)$},
      ~r{lib/athel_web/views/.*(ex)$},
      ~r{lib/athel_web/templates/.*(eex)$}
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Configure your database
config :athel, Athel.Repo,
  username: "athel",
  password: "athel",
  database: "athel_dev",
  hostname: "localhost",
  pool_size: 10

config :athel, Athel.Nntp,
  port: 8119,
  hostname: "localhost",
  pool_size: 10,
  timeout: 61_000,
  keyfile: Path.expand("../priv/keys/testing.key", __DIR__),
  certfile: Path.expand("../priv/keys/testing.cert", __DIR__),
  cacertfile: Path.expand("../priv/keys/example.com.crt", __DIR__),
  max_request_size: 75_000_000,
  max_attachment_size: 20_000_000,
  max_attachment_count: 3

config :athel, Athel.Vault,
  ciphers: [
    default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: Base.decode64!("7/TfD+toi48MB2bpPZRnsfc8pgvpY1QEQWvfYyfGsVw=")}
  ]
