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
    formatted = Enum.reduce(headers, [], fn ({key, value}, acc) ->
      format_header({format_key(key), value}, acc)
    end)
    [formatted, "\r\n"]
  end

  defp format_header({_, value}, acc) when is_nil(value) do
    acc
  end
  # multiple header values
  defp format_header({key, values}, acc) when is_list(values) do
    Enum.reduce(values, acc, &format_header({key, &1}, &2))
  end
  # paramterized header
  defp format_header({key, %{value: value, params: params}}, acc) do
    formatted_params = Enum.reduce(params, [], &format_param/2)
    [acc, key, ": ", value, formatted_params, "\r\n"]
  end
  # default
  defp format_header({key, value}, acc) do
    [acc, key, ": ", value, "\r\n"]
  end

  defp format_param({key, value}, acc) do
    formatted_key = String.downcase(key)
    if value =~ ~r/\s/ do
      [acc, "; ", formatted_key, "=\"", value, "\""]
    else
      [acc, "; ", formatted_key, "=", value]
    end
  end

  defp format_key("MESSAGE-ID"), do: "Message-ID"
  defp format_key("MIME-VERSION"), do: "MIME-Version"
  defp format_key(key) do
    key
    |> String.split("-")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join("-")
  end
end

