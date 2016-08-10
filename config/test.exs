use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :athel, Athel.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :athel, Athel.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "athel_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :athel, Athel.Nntp,
  port: 8119,
  pool_size: 10,
  timeout: 5_000,
  keyfile: Path.expand("../priv/testing.key", __DIR__),
  certfile: Path.expand("../priv/testing.crt", __DIR__)
