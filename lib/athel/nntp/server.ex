defmodule Athel.Nntp.Server do
  use Supervisor

  def start_link(port) do
    Supervisor.start_link(__MODULE__, port, name: __MODULE__)
  end

  def init(port) do
    pool_size = 100

    children = [
      # :ranch_sup already started by phoenix/cowboy
      :ranch.child_spec(
        :nntp,
        pool_size,
        :ranch_tcp, [port: port],
        Athel.Nntp.Protocol, []
      )
    ]

    supervise(children, strategy: :one_for_one)
  end

end
