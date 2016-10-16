defmodule Athel.Nntp.Protocol do
  @behaviour :ranch_protocol

  require Logger

  alias Athel.Nntp.{SessionHandler, Parser, Formattable}

  defmodule CommunicationError do
    defexception message: "Error while communicating with client"
  end

  defmodule State do
    defstruct [:transport,
               :socket,
               :buffer,
               :session_handler,
               :opts]
    @type t :: %State{transport: :ranch_transport,
                      socket: :inet.socket,
                      buffer: iodata,
                      session_handler: pid,
                      opts: Athel.Nntp.opts}
  end

  @spec start_link(:ranch.ref, :inet.socket, module, Athel.Nntp.opts) :: {:ok, pid}
  def start_link(_ref, socket, transport, opts) do
    # no accept_ack(ref) because connection always starts as plain tcp
    {:ok, session_handler} = SessionHandler.start_link()
    state = %State{socket: socket,
                   transport: transport,
                   session_handler: session_handler,
                   buffer: [],
                   opts: opts
                  }
    pid = spawn_link(__MODULE__, :init, [state])
    {:ok, pid}
  end

  @spec init(State.t) :: nil
  def init(state) do
    Logger.info "Welcoming client"
    send_status(state, {200, "WELCOME FRIEND"})
    recv_command(state)
  end

  defp recv_command(state) do
    {action, buffer} =
      case read_and_parse(state, &Parser.parse_command/1) do
        {:ok, command, buffer} ->
          {GenServer.call(state.session_handler, command), buffer}
        {:error, type} ->
          {{:continue, {501, "Syntax error in #{type}"}}, []}
      end
    state = %{state | buffer: buffer}

    Logger.debug "Next NNTP protocol action is #{inspect action}"

    case action do
      {:continue, response} ->
        send_status(state, response)
        recv_command(state)
      #TODO: count errors and kill connection if too many occur
      {:error, response} ->
        # we're in a bad state, clear any remaining input
        state = %{state | buffer: []}
        send_status(state, response)
        recv_command(state)
      {{:recv_article, type}, response} ->
        unless is_nil(response), do: send_status(state, response)
        recv_article(type, state)
      # clear remaining article out of buffer without clearing any
      # of the following commands
      {:kill_article, response} ->
        send_status(state, response)
        kill_article(state)
      {:start_tls, {good_response, bad_response}} ->
        start_tls(state, good_response, bad_response)
      {:quit, response} ->
        send_status(state, response)
        close(state)
    end
  end

  defp recv_article(type, state) do
    message =
      with {:ok, headers, buffer} <- read_and_parse(state, &Parser.parse_headers/1),
           {:ok, body, buffer} <- read_and_parse(%{state | buffer: buffer},
             &Parser.parse_multiline/1),
             message_name <- "#{type}_article" |> String.to_atom,
      do: {{message_name, headers, body}, buffer}

    {response, buffer} =
      case message do
        {:error, type} ->
          message = "Syntax error in #{type}"
          Logger.debug message
          {{501, message}, []}
        {message, buffer} ->
          {GenServer.call(state.session_handler, message), buffer}
      end

    send_status(state, response)
    recv_command(%{state | buffer: buffer})
  end

  defp kill_article(state) do
    buffer =
      with {:ok, _, buffer} <- read_and_parse(state, &Parser.parse_headers/1),
           {:ok, _, buffer} <- read_and_parse(%{state | buffer: buffer},
             &Parser.parse_multiline/1),
      do: buffer

    buffer =
      case buffer do
        {:error, } -> []
        buffer -> buffer
      end

    recv_command(%{state | buffer: buffer})
  end

  defp start_tls(state = %State{transport: :ranch_tcp}, good_response, _) do
    send_status(state, good_response)

    opts = [keyfile: state.opts[:keyfile],
            certfile: state.opts[:certfile],
            cacertfile: state.opts[:cacertfile],
            verify: :verify_none]
    result = :ssl.ssl_accept(state.socket, opts, state.opts[:timeout])
    case result do
      {:ok, socket} ->
        %{state | transport: :ranch_ssl, socket: socket}
        |> recv_command
      {:error, reason} ->
        Logger.error "Failed to accept SSL: #{inspect reason}"
        close(state)
    end
  end

  defp start_tls(state = %State{transport: :ranch_ssl}, _, bad_response) do
    send_status(state, bad_response)
    recv_command(state)
  end

  defp read_and_parse(state = %State{buffer: buffer}, parser) do
    buffer =
      case buffer do
        [] -> read(state)
        "" -> read(%{state | buffer: []})
        _ -> buffer
      end

    case parser.(buffer) do
      :need_more ->
        next_state = %{state | buffer: read(state)}
        read_and_parse(next_state, parser)
      other -> other
    end
  end

  defp read(%State
    {transport: transport,
     socket: socket,
     buffer: buffer,
     opts: opts}) do
    case transport.recv(socket, 0, opts[:timeout]) do
      {:ok, received} ->
        buffer = [buffer, received]
        bytes_read = IO.iodata_length(buffer)
        if bytes_read > opts[:max_request_size] do
          raise CommunicationError, message: "Max request buffer length exceeded"
        end
        buffer
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
    body = body |> Formattable.format
    case transport.send(socket, "#{code} #{message}\r\n#{body}") do
      :ok -> ()
      {:error, reason} ->
        raise CommunicationError, message: "Failed to send status with body to client: #{reason}"
    end
  end

  defp close(state) do
    case state.transport.close(state.socket) do
      :ok -> ()
      {:error, reason} -> Logger.error "Failed to close connection: #{inspect reason}"
    end
  end

end
