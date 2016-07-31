defmodule Athel.Nntp.ClientHandler do
  use GenServer

  require Logger
  require Athel.Nntp.Defs
  import Athel.Nntp.Defs
  alias Athel.Nntp.Parser
  alias Athel.Nntp.Formatter

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  def init(socket) do
    Logger.info "Welcoming client"
    send_status(socket, {200, "WELCOME, FRIEND"})
    spawn_link(__MODULE__, :recv_command, [self(), socket, []])
    {:ok, socket}
  end

  # Command handling

  defmacrop respond(type, response) do
    quote do: {:reply, {unquote(type), unquote(response)}, var!(state)}
  end

  check_argument_count("CAPABILITIES", 0)
  def handle_call({"CAPABILITIES", _}, _from, state) do
    capabilities = ["VERSION 2", "POST"]
    respond(:continue, {101, "Listing capabilities", capabilities})
  end

  check_argument_count("QUIT", 0)
  def handle_call({"QUIT", _}, _from, state) do
    respond(:quit, {205, "SEE YA"})
  end

  def handle_call({other, _}, _from, state) do
    respond(:continue, {501, "Syntax error in #{other}"})
  end

  # Socket recv/send

  def recv_command(handler, socket, buffer) do
    {action, rest} = case read_command(socket, buffer) do
                       {:ok, command, rest} -> {GenServer.call(handler, command), rest}
                       {:error, type} -> {{:continue, {501, "Syntax error in #{type}"}}, []}
                     end

    case action do
      {:continue, response} ->
        send_status(socket, response)
        recv_command(handler, socket, [rest])
      {:quit, response} ->
        send_status(socket, response)
        :ok = :gen_tcp.close(socket)
        Athel.Nntp.Server.close_handler(handler)
    end
  end

  defp read_command(socket, buffer) do
    #warning: [""] won't register as empty, will a redundant
    # trigger a parse() -> :need_more loop
    buffer = if Enum.empty?(buffer), do: read(socket, buffer), else: buffer

    case Parser.parse_command(buffer) do
      {:ok, {name, arguments}, rest} -> {:ok, {String.upcase(name), arguments}, rest}
      {:error, type} -> {:error, type}
      :need_more -> read_command(socket, read(socket, buffer))
    end
  end

  defp read(socket, buffer) do
    {:ok, received} = :gen_tcp.recv(socket, 0)
    [buffer, received]
  end

  defp send_status(socket, {code, message}) do
    :gen_tcp.send(socket, "#{code} #{message}\r\n")
  end

  defp send_status(socket, {code, message, lines}) do
    multiline = Formatter.format_multiline(lines)
    :gen_tcp.send(socket, "#{code} #{message}\r\n#{multiline}")
  end

end
