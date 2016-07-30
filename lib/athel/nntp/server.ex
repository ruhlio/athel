defmodule Athel.Nntp.Server do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def handle_client(socket) do
    {:ok, {client_addr, client_port}} = :inet.peername(socket)
    client_addr = Tuple.to_list(client_addr) |> Enum.join(".")
    Supervisor.start_child(__MODULE__,
      {
        "#{Athel.Nntp.ClientHandler}@#{client_addr}:#{client_port}",
        {Athel.Nntp.ClientHandler, :start_link, [socket]},
        :temporary,
        5_000,
        :worker,
        [GenServer]
      })
  end

  def init(:ok) do
    children = [
      worker(Athel.Nntp.ClientAcceptor, [8119])
    ]

    supervise(children, strategy: :one_for_one)
  end

end
