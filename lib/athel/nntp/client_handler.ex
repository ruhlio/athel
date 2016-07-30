defmodule Athel.Nntp.ClientHandler do
  use GenServer
  require Logger
  alias Athel.Nntp.Parser

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  def init(socket) do
    Logger.info "Welcoming client"
    send_status(socket, 200, "WELCOME, FRIEND")
    spawn_link(__MODULE__, :recv_command, [self(), socket, []])
    {:ok, socket}
  end

  # Sending

  def handle_cast({:capabilities}, _sender) do
    IO.puts("capabilities")
  end

  def handle_cast({:syntax_error, source}, _sender) do
    IO.puts("syntax_error #{inspect source}")
  end

  def handle_cast({:invalid_command, command_name}, _sender) do
    IO.puts("invalid_command #{command_name}")
  end

  defp send_status(socket, code, message) do
    :gen_tcp.send(socket, "#{code} #{message}\r\n")
  end

  # Receiving

  def recv_command(handler, socket, buffer) do
    {cast, rest} = case read_command(socket, buffer) do
                     {:ok, command, rest} -> {process_command(command), rest}
                     {:error, type} -> {{:syntax_error, type}, []}
                   end

    GenServer.cast(handler, cast)
    recv_command(handler, socket, rest)
  end

  defp process_command({"CAPABILITIES", _}) do
    {:capabilities}
  end

  defp process_command({other, _}) do
    {:invalid_command, other}
  end

  defp read_command(socket, buffer) do
    buffer = if Enum.empty?(buffer), do: read(socket, buffer), else: buffer

    case Parser.parse_command(buffer) do
      {:ok, {name, arguments}, rest} -> {{String.upcase(name), arguments}, rest}
      {:error, type} -> {:error, type}
      :need_more -> read_command(socket, read(socket, buffer))
    end
  end

  defp read(socket, buffer) do
    {:ok, received} = :gen_tcp.recv(socket, 0)
    buffer ++ received
  end

end
