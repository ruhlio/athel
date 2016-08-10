defmodule Athel.Nntp do
  use Supervisor

  @type opts :: [port: non_neg_integer,
                 pool_size: non_neg_integer,
                 timeout: non_neg_integer,
                 keyfile: String.t,
                 certfile: String.t
                ]

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    config = Application.fetch_env!(:athel, __MODULE__)

    children = [
      # :ranch_sup already started by phoenix/cowboy
      :ranch.child_spec(
        :nntp,
        config[:pool_size],
        :ranch_tcp, [port: config[:port]],
        Athel.Nntp.Protocol, config
      )
    ]

    supervise(children, strategy: :one_for_one)
  end

end
