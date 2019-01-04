defmodule AthelWeb.ViewCommon do
  use Timex
  import Phoenix.HTML
  import Phoenix.HTML.Tag

  def format_date(date) do
    Timex.format!(date, "%a, %d %b %Y %T", :strftime)
  end

  def error_class(changeset, input) do
    if changeset.errors[input] do
      "input-error"
    else
      ""
    end
  end

  def format_article_body(body) do
    paragraphs = body
    |> Enum.chunk_by(&(&1 == ""))
    |> Enum.filter(&(&1 != [""]))

    Enum.map(paragraphs, fn paragraph ->
      lines = Enum.map(paragraph, &([process_line(&1), tag(:br)]))
      content_tag(:p, lines)
    end)
  end

  @quote_class_count 3

  defp process_line(line) do
    case count_quotes(line) do
      0 -> line
      level ->
        class_level = rem(level, @quote_class_count)
        content_tag(:span, line, class: "quote-#{class_level}")
    end
  end

  defp count_quotes(line), do: count_quotes(line, 0)
  defp count_quotes(<<">", rest :: binary>>, count), do: count_quotes(rest, count + 1)
  defp count_quotes(_, count), do: count
end
