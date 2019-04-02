defmodule Athel.Application do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      supervisor(Athel.Repo, []),
      supervisor(AthelWeb.Endpoint, []),
      supervisor(Athel.Nntp.Supervisor, []),
      supervisor(Athel.Event.Supervisor, []),
      supervisor(Athel.ScraperSupervisor, []),
      worker(Athel.UserCache, [])
    ]

    opts = [strategy: :one_for_one, name: Athel.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    AthelWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
