defprotocol Athel.Nntp.Formattable do
  @spec format(t) :: iodata
  def format(formattable)
end

defimpl Athel.Nntp.Formattable, for: List do
  def format(list) do
    [Enum.reduce(list, [], &escape_line/2), ".\r\n"]
  end

  defp escape_line(<<".", rest :: binary>>, acc) do
    [acc, "..", rest, "\r\n"]
  end

  defp escape_line(line, acc) when is_number(line) or is_boolean(line) do
    escape_line(to_string(line), acc)
  end

  defp escape_line(line, acc) do
    [acc, line, "\r\n"]
  end

end

defimpl Athel.Nntp.Formattable, for: Range do
  alias Athel.Nntp.Formattable

  def format(range) do
    range |> Enum.to_list |> Formattable.format
  end
end

defimpl Athel.Nntp.Formattable, for: Map do
  def format(headers) do
    [Enum.reduce(headers, [], &format_header/2), "\r\n"]
  end

  defp format_header({_, value}, acc) when is_nil(value) do
    acc
  end

  defp format_header({key, value}, acc) do
    [acc, [key, ": ", value, "\r\n"]]
  end

end

