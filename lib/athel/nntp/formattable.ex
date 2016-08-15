defmodule Athel.Nntp.Format do
  alias Athel.Article

  @spec format_multiline(list(String.t | String.Chars.t)) :: String.t
  def format_multiline(lines) do
    [Enum.reduce(lines, [], &escape_line/2), ".\r\n"]
    |> IO.iodata_to_binary
  end

  @spec format_article(Athel.Article.t) :: String.t
  def format_article(article) do
    headers = article |> Article.get_headers |> format_headers
    body = article.body |> format_multiline

    [headers, body] |> IO.iodata_to_binary
  end

  @spec format_headers(%{optional(String.t) => String.t}) :: String.t
  def format_headers(headers) do
    [Enum.reduce(headers, [], &format_header/2), "\r\n"]
  end

  defp format_header({_, value}, acc) when is_nil(value) do
    acc
  end

  defp format_header({key, value}, acc) do
    [acc, [key, ": ", value, "\r\n"]]
  end

  defp escape_line(<<".", rest :: binary>>, acc) do
    [acc, "..", rest, "\r\n"]
  end

  defp escape_line(line, acc) when is_binary(line) do
    [acc, line, "\r\n"]
  end

  defp escape_line(line, acc) do
    escape_line(to_string(line), acc)
  end

end

defprotocol Athel.Nntp.Formattable do
  @spec format(t) :: String.t
  def format(formattable)
end

defimpl Athel.Nntp.Formattable, for: List do
  import Athel.Nntp.Format

  def format(list) do
    format_multiline(list)
  end
end

defimpl Athel.Nntp.Formattable, for: Range do
  import Athel.Nntp.Format

  def format(range) do
    format_multiline(range)
  end
end

defimpl Athel.Nntp.Formattable, for: Map do
  import Athel.Nntp.Format

  def format(headers) do
    format_headers(headers)
  end
end

defimpl Athel.Nntp.Formattable, for: Athel.Article do
  import Athel.Nntp.Format

  def format(article) do
    format_article(article)
  end
end
