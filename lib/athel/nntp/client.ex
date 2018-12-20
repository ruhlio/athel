defmodule Athel.Nntp.Client do
  alias Athel.Nntp.Parser
  require Logger

  @spec connect(String.t | :inet.ip_address, :inet.port_number) :: {:ok, :inet.socket} | {:error, String.t}
  def connect(address, port) do
    with {:ok, socket} <- :gen_tcp.connect(String.to_charlist(address), port, active: false),
         {:ok, _greeting} <- :gen_tcp.recv(socket, 0),
      do: {:ok, socket}
      |> format_error
  end

  @spec list(:inet.socket, list(String.t)) :: {:ok, list(String.t)} | {:error, String.t}
  def list(socket, arguments \\ []) do
    command =
    if Enum.empty?(arguments) do
      "LIST\r\n"
    else
      "LIST #{Enum.join(arguments, " ")}\r\n"
    end

    with :ok <- :gen_tcp.send(socket, command),
         {:ok, {215, _}, body} <- read_and_parse(socket, [], &Parser.parse_code_line/2),
         {:ok, lines, _} <- read_and_parse(socket, body, &Parser.parse_multiline/2),
    do: {:ok, lines}
    |> format_error
  end

  @spec set_group(:inet.socket, String.t) :: :ok | {:error, String.t}
  def set_group(socket, group) do
    with :ok <- :gen_tcp.send(socket, "GROUP #{group}\r\n"),
         {:ok, {211, _}, _} <- read_and_parse(socket, [], &Parser.parse_code_line/2),
    do: :ok
    |> format_error
  end

  @spec xover(:inet.socket, integer) :: {:ok, []} | {:error, list(String.t)}
  def xover(socket, start) do
    with :ok <- :gen_tcp.send(socket, "XOVER #{start}-\r\n"),
         {:ok, {224, _}, body} <- read_and_parse(socket, [], &Parser.parse_code_line/2),
         {:ok, lines, _} <- read_and_parse(socket, body, &Parser.parse_multiline/2),
      do: {:ok, lines}
      |> format_error
  end

  @spec get_article(:inet.socket, String.t) :: {:ok, {Map.t, list(String.t)}} | {:error, String.t}
  def get_article(socket, id) do
    with :ok <- :gen_tcp.send(socket, "ARTICLE <#{id}>\r\n"),
         {:ok, {220, _}, header_buffer} <- read_and_parse(socket, [], &Parser.parse_code_line/2),
         {:ok, headers, body_buffer} <- read_and_parse(socket, header_buffer, &Parser.parse_headers/2),
         {:ok, body, _} <- read_and_parse(socket, body_buffer, &Parser.parse_multiline/2),
    do: {:ok, {headers, body}}
    |> format_error
  end

  @spec quit(:inet.socket) :: :ok | {:error, String.t}
  def quit(socket) do
    with :ok <- :gen_tcp.send(socket, "QUIT\r\n"),
      do: :gen_tcp.close(socket)
    |> format_error
  end

  defp read_and_parse(socket, buffer, parser, parser_state \\ nil) do
    next_buffer =
    if "" == buffer or [] == buffer do
      read(socket, buffer)
    else
      buffer
    end

    if is_error(next_buffer) do
      next_buffer
    else
      case parser.(next_buffer, parser_state) do
        {:need_more, parser_state} -> read_and_parse(socket, [], parser, parser_state)
        other -> other
      end
    end
  end

  defp read(socket, buffer) do
    case :gen_tcp.recv(socket, 0, 10_000) do
      {:ok, received} -> [buffer, received]
      error -> error
    end
  end

  defp is_error({:error, _}), do: true
  defp is_error(_), do: false

  defp format_error(:ok), do: :ok
  defp format_error(tup) when is_tuple(tup), do: tup
  defp format_error(other), do: {:error, other}

end
