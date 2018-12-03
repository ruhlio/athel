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

  @spec groups(:inet.socket) :: {:ok, []} | {:error, String.t}
  def groups(socket) do
    with :ok <- :gen_tcp.send(socket, "LIST NEWSGROUPS\r\n"),
         {:ok, {215, _}, body} <- read_and_parse(socket, [], &Parser.parse_code_line/1),
         {:ok, lines, _} <- read_and_parse(socket, body, &Parser.parse_multiline/1)
    do
      groups = Enum.map(lines, fn line -> line |> String.split |> List.first end)
      {:ok, groups}
    end
    |> format_error
  end

  @spec set_group(:inet.socket, String.t) :: :ok | {:error, String.t}
  def set_group(socket, group) do
    :gen_tcp.send(socket, "GROUP #{group}\r\n") |> format_error
  end

  @spec xover(:inet.socket) :: {:ok, []} | {:error, String.t}
  def xover(socket) do
    with :ok <- :gen_tcp.send(socket, "XOVER\r\n"),
         {:ok, {224, _}, body} <- read_and_parse(socket, [], &Parser.parse_code_line/1),
         {:ok, lines, _} <- read_and_parse(socket, body, &Parser.parse_multiline/1)
    do
      article_ids = Enum.map(lines, fn line -> line |> String.split |> List.at(4) end)
      case article_ids do
        nil -> {:error, "Invalid server response"}
        ids -> {:ok, ids}
      end
    end |> format_error
  end

  @spec get_article(:inet.socket, String.t) :: {:ok, {Map.t, []}} | {:error, String.t}
  def get_article(socket, id) do
    with :ok <- :gen_tcp.send(socket, "ARTICLE <#{id}>\r\n"),
         {:ok, {223, _}, buffer} <- read_and_parse(socket, [], &Parser.parse_code_line/1),
         {:ok, headers, buffer} <- read_and_parse(socket, buffer, &Parser.parse_headers/1),
         {:ok, body, _} <- read_and_parse(socket, buffer, &Parser.parse_multiline/1),
    do: {:ok, {headers, body}}
    |> format_error
  end

  @spec quit(:inet.socket) :: :ok | {:error, String.t}
  def quit(socket) do
    with :ok <- :gen_tcp.send(socket, "QUIT\r\n"),
      do: :gen_tcp.close(socket)
    |> format_error
  end

  defp read_and_parse(socket, buffer, parser) do
    buffer =
      case buffer do
        [] -> read(socket, buffer)
        "" -> read(socket, [])
        _ -> buffer
      end

    case parser.(buffer) do
      :need_more -> read_and_parse(socket, read(socket, buffer), parser)
      other -> other
    end
  end

  defp read(socket, buffer) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, received} ->
        buffer = [buffer, received]
        bytes_read = IO.iodata_length(buffer)
        buffer
      error -> error
    end
  end

  defp format_error({:error, reason}) when is_atom(reason) do
    {:error, :inet.format_error(reason)}
  end
  defp format_error(tup) when is_tuple(tup), do: tup
  defp format_error(other), do: {:error, other}

end
