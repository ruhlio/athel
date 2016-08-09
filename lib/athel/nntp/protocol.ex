defmodule Athel.Nntp.Protocol do
  @behaviour :ranch_protocol

  require Logger

  alias Athel.Nntp.{SessionHandler, Parser, Formattable}

  defmodule CommunicationError do
    defexception message: "Error while communicating with client"
  end

  defmodule State do
    defstruct transport: nil, socket: nil, buffer: [], session_handler: nil
  end

  @spec start_link(:ranch.ref, :inet.socket, module, list) :: {:ok, pid}
  def start_link(ref, socket, transport, _opts) do
    {:ok, session_handler} = SessionHandler.start_link()
    pid = spawn_link(__MODULE__, :init, [ref, socket, transport, session_handler])
    {:ok, pid}
  end

  @spec start_link(:ranch.ref, :inet.socket, module, list) :: nil
  def init(ref, socket, transport, session_handler) do
    :ok = :ranch.accept_ack(ref)

    Logger.info "Welcoming client"
    state = %State{socket: socket, transport: transport, session_handler: session_handler}
    send_status(state, {200, "WELCOME FRIEND"})
    recv_command(state)
  end

  def recv_command(state) do
    {action, buffer} =
      case read_and_parse(state, &Parser.parse_command/1) do
        {:ok, command, buffer} -> {GenServer.call(state.session_handler, command), buffer}
        {:error, type} -> {{:continue, {501, "Syntax error in #{type}"}}, []}
      end
    state = %{state | buffer: buffer}

    case action do
      {:continue, response} ->
        send_status(state, response)
        recv_command(state)
      #TODO: count errors and kill connection if too many occur
      {:error, response} ->
        send_status(state, response)
        recv_command(state)
      {:recv_article, response} ->
        send_status(state, response)
        recv_article(state)
      {:quit, response} ->
        send_status(state, response)
        :ok = state.transport.close(state.socket)
    end
  end

  defp recv_article(state) do
    article =
      with {:ok, headers, buffer} <- read_and_parse(state, &Parser.parse_headers/1),
           {:ok, body, buffer} <- read_and_parse(
             %{state | buffer: buffer}, &Parser.parse_multiline/1),
      do: {{:article, headers, body}, buffer}

    {response, buffer} =
      case article do
        {:error, type} -> {{501, "Syntax error in #{type}"}, []}
        {article, buffer} -> {GenServer.call(state.session_handler, article), buffer}
      end

    send_status(state, response)
    recv_command(%{state | buffer: buffer})
  end

  defp read_and_parse(
    state = %State{transport: transport, socket: socket, buffer: buffer}, parser) do
    buffer =
      case buffer do
        [] -> read(transport, socket, buffer)
        "" -> read(transport, socket, [])
        _ -> buffer
      end

    case parser.(buffer) do
      :need_more ->
        next_state = %{state | buffer: read(transport, socket, buffer)}
        read_and_parse(next_state, parser)
      other -> other
    end
  end

  defp read(transport, socket, buffer) do
    case transport.recv(socket, 0, 5_000) do
      {:ok, received} -> [buffer, received]
      {:error, reason} ->
        raise CommunicationError, message: "Failed to read from client: #{reason}"
    end
  end

  defp send_status(%State{transport: transport, socket: socket}, {code, message}) do
    case transport.send(socket, "#{code} #{message}\r\n") do
      :ok -> ()
      {:error, reason} ->
        raise CommunicationError, message: "Failed to send status to client: #{reason}"
    end
  end

  defp send_status(%State{transport: transport, socket: socket}, {code, message, body}) do
    body = Formattable.format(body)
    case transport.send(socket, "#{code} #{message}\r\n#{body}") do
      :ok -> ()
      {:error, reason} ->
        raise CommunicationError, message: "Failed to send status with body to client: #{reason}"
    end
  end

end
