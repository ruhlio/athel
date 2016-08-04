defmodule Athel.Nntp.ClientHandler do
  use GenServer

  require Logger
  import Ecto.Query

  alias Athel.Repo
  alias Athel.Group
  require Athel.Nntp.Defs
  import Athel.Nntp.Defs
  alias Athel.Nntp.Parser
  alias Athel.Nntp.Format

  defmodule CommunicationError do
    defexception message: "Error while communicating with client"
  end

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  def init(socket) do
    Logger.info "Welcoming client"
    send_status(socket, {200, "WELCOME FRIEND"})
    spawn_link(__MODULE__, :recv_command, [self(), socket, []])
    {:ok, socket}
  end

  # Command handling

  defmacrop respond(type, response) do
    quote do: {:reply, {unquote(type), unquote(response)}, var!(state)}
  end

  check_argument_count("CAPABILITIES", 0)
  def handle_call({"CAPABILITIES", _}, _from, state) do
    capabilities = ["VERSION 2", "POST", "LIST ACTIVE NEWGROUPS"]
    respond(:continue, {101, "Listing capabilities", capabilities})
  end

  check_argument_count("QUIT", 0)
  def handle_call({"QUIT", _}, _from, state) do
    respond(:quit, {205, "SEE YA"})
  end

  #TODO: LIST ACTIVE with wildmat
  check_argument_count("LIST", 2)

  def handle_call({"LIST", []}, from, state) do
    handle_call({"LIST", ["ACTIVE"]}, from, state)
  end

  def handle_call({"LIST", ["ACTIVE"]}, _from, state) do
    groups = Repo.all(
      from g in Group,
      order_by: :name)
      |> Enum.map(&("#{&1.name} #{&1.high_watermark} #{&1.low_watermark} #{&1.status}"))
    respond(:continue, {215, "Listing groups", groups})
  end

  def handle_call({"LIST", ["NEWSGROUPS"]}, _from, state) do
    groups = Repo.all(
      from g in Group,
      order_by: :name)
      |> Enum.map(&("#{&1.name} #{&1.description}"))
    respond(:continue, {215, "Listing group descriptions", groups})
  end

  def handle_call({"LIST", _}, _from, state) do
    respond(:continue, {501, "Invalid LIST arguments"})
  end

  check_argument_count("LISTGROUP", 2)
  def handle_call({"LISTGROUP", [_1, _2]}, _from, state) do
    respond(:continue, {101, "TODO"})
  end

  check_argument_count("ARTICLE", 1)
  def handle_call({"ARTICLE", [id]}, _from, state) do
    respond(:continue, {101, "TODO"})
  end

  check_argument_count("POST", 0)
  def handle_call({"POST", []}, _from, state) do
    respond(:continue, {101, "TODO"})
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
    case :gen_tcp.recv(socket, 0) do
      {:ok, received} -> [buffer, received]
      {:error, :closed} -> raise CommunicationError, message: "Client terminated connection prematurely"
    end
  end

  defp send_status(socket, {code, message}) do
    :gen_tcp.send(socket, "#{code} #{message}\r\n")
  end

  defp send_status(socket, {code, message, lines}) do
    multiline = Format.format_multiline(lines)
    :gen_tcp.send(socket, "#{code} #{message}\r\n#{multiline}")
  end

end
