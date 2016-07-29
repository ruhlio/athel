defmodule Athel.Nntp.Server do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def handle_client(socket) do
    {:ok, client_addr, client_port} = :inet.peername(socket)
    Supervisor.start_child(__MODULE__, [socket],
      name: "#{Athel.Nntp.ClientHandler}@#{client_addr}:#{client_port}")
  end

  def init(:ok) do
    children = [
      worker(Athel.Nntp.ClientHandler, [], restart: :temporary)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end

end
