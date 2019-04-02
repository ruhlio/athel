defmodule Athel.Event.Supervisor do
  use Supervisor

  import Supervisor.Spec

  def start_link() do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children = [
      worker(Athel.Event.NntpBroadcaster, []),
      worker(Athel.Event.ModerationHandler, [])
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

end
