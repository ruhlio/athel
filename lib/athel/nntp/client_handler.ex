defmodule Athel.Nntp.ClientHandler do
  use GenServer
  require Logger

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  def init(socket) do
    Logger.info "Welcoming client"
    send_status(socket, 200, "WELCOME, FRIEND")
    spawn_link(__MODULE__, :recv_command, [socket, self(), []])
    {:ok, socket}
  end

  # Sending

  def handle_call({:capabilities}) do
    
  end

  defp send_status(socket, code, message) do
    :gen_tcp.send(socket, "#{code} #{message}\r\n")
  end

  # Receiving

  defp recv_command(socket, handler, buffer) do
    buffer = if Enum.empty? buffer do
      {:ok, received} = :gen_tcp.recv(socket, 0)
      received
    else
      buffer
    end

  end

end
