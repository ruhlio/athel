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

  @spec list_groups(:inet.socket) :: {:ok, list(String.t)} | {:error, String.t}
  def list_groups(socket) do
    with :ok <- :gen_tcp.send(socket, "LIST\r\n"),
         {:ok, {215, _}, body} <- read_and_parse(socket, [], &Parser.parse_code_line/1),
         {:ok, lines, _} <- read_and_parse(socket, body, &Parser.parse_multiline/2, [])
    do
      groups = Enum.map(lines, fn line -> line |> String.split |> List.first end)
      {:ok, groups}
    end
    |> format_error
  end

  @spec set_group(:inet.socket, String.t) :: :ok | {:error, String.t}
  def set_group(socket, group) do
    with :ok <- :gen_tcp.send(socket, "GROUP #{group}\r\n"),
         {:ok, {211, _}, _} <- read_and_parse(socket, [], &Parser.parse_code_line/1),
    do: :ok
    |> format_error
  end

  @spec xover(:inet.socket, integer) :: {:ok, []} | {:error, String.t}
  def xover(socket, start) do
    with :ok <- :gen_tcp.send(socket, "XOVER #{start}-\r\n"),
         {:ok, {224, _}, body} <- read_and_parse(socket, [], &Parser.parse_code_line/1),
         {:ok, lines, _} <- read_and_parse(socket, body, &Parser.parse_multiline/2, [])
    do
      article_ids = Enum.map(lines, fn line -> line |> String.split |> Enum.at(4) end)
      case article_ids do
        nil -> {:error, "Invalid server response"}
        ids -> {:ok, ids}
      end
    end |> format_error
  end

  @spec get_article(:inet.socket, String.t) :: {:ok, {Map.t, list(String.t)}} | {:error, String.t}
  def get_article(socket, id) do
    with :ok <- :gen_tcp.send(socket, "ARTICLE <#{id}>\r\n"),
         {:ok, {223, _}, buffer} <- read_and_parse(socket, [], &Parser.parse_code_line/1),
         {:ok, headers, buffer} <- read_and_parse(socket, buffer, &Parser.parse_headers/1),
         {:ok, body, _} <- read_and_parse(socket, buffer, &Parser.parse_multiline/2, []),
    do: {:ok, {headers, body}}
    |> format_error
  end

  @spec quit(:inet.socket) :: :ok | {:error, String.t}
  def quit(socket) do
    with :ok <- :gen_tcp.send(socket, "QUIT\r\n"),
      do: :gen_tcp.close(socket)
    |> format_error
  end

  defp read_and_parse(socket, buffer, parser, acc \\ nil) do
    buffer =
      case buffer do
        [] -> read(socket, buffer)
        "" -> read(socket, [])
        _ -> buffer
      end

    cond do
      is_error(buffer) -> buffer
      nil == acc ->
        case parser.(buffer) do
          :need_more -> read_and_parse(socket, read(socket, buffer), parser)
          other -> other
        end
      is_list(acc) ->
        case parser.(buffer, acc) do
          {:need_more, acc} -> read_and_parse(socket, read(socket, buffer), parser, acc)
          other -> other
        end
    end
  end

  defp read(socket, buffer) do
    case :gen_tcp.recv(socket, 0) do
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
