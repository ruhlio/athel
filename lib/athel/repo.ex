defmodule Athel.Repo do
  use Ecto.Repo,
    otp_app: :athel,
    adapter: Ecto.Adapters.Postgres
end
