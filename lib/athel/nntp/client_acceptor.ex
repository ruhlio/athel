defmodule Athel.Nntp.ClientAcceptor do
  use GenServer
  require Logger
  alias Athel.Nntp.Server

  def start_link(port) do
    GenServer.start_link(__MODULE__, port, [])
  end

  def init(port) do
    {:ok, socket} = :gen_tcp.listen(port,
      [:binary, packet: :raw, active: false, reuseaddr: true])
    Logger.info "Accepting connections on port #{port}"
    pid = spawn_link(__MODULE__, :accept_connection, [socket])
    {:ok, pid}
  end

  def accept_connection(socket) do
    {:ok, client_socket} = :gen_tcp.accept(socket)
    Server.handle_client(client_socket)
    accept_connection(socket)
  end

end
