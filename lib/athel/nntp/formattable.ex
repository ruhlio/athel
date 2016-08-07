defmodule Athel.Nntp.Format do

  @spec format_multiline(list(String.t | String.Chars.t)) :: String.t
  def format_multiline(lines) do
    [Enum.reduce(lines, [], &escape_line/2), ".\r\n"]
    |> IO.iodata_to_binary
  end

  @spec format_article(Athel.Article.t) :: String.t
  def format_article(article) do
    headers = format_headers %{
      "Newsgroups" => format_article_groups(article.groups),
      "Message-ID" => format_message_id(article.message_id),
      "References" => format_message_id(article.reference),
      "From" => article.from,
      "Subject" => article.subject,
      "Date" => Timex.format!(article.date, "%d %b %Y %H:%M:%S %z", :strftime),
      "Content-Type" => article.content_type
    }
    body = article.body |> String.split("\n") |> format_multiline

    [headers, body] |> IO.iodata_to_binary
  end

  defp format_headers(headers) do
    [Enum.reduce(headers, [], &format_header/2), "\r\n"]
  end

  defp format_header({_, value}, acc) when is_nil(value) do
    acc
  end

  defp format_header({key, value}, acc) do
    [acc, [key, ": ", value, "\r\n"]]
  end

  defp format_article_groups(groups) do
    Enum.reduce(groups, :first, fn
      group, :first -> [group.name]
      group, acc -> [acc, ?,, group.name]
    end)
  end

  defp format_message_id(message_id) when is_nil(message_id) do
    nil
  end

  defp format_message_id(message_id) do
    [?<, message_id, ?>]
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

defimpl Athel.Nntp.Formattable, for: Athel.Article do
  import Athel.Nntp.Format

  def format(article) do
    format_article(article)
  end
end
