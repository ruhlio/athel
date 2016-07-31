defmodule Athel.Nntp.Formatter do

  @spec format_multiline(list(String.t)) :: String.t
  def format_multiline(lines) do
    [Enum.reduce(lines, [], &escape_line/2), ".\r\n"]
    |> IO.iodata_to_binary
  end

  defp escape_line(<<".", rest :: binary>>, acc) do
    [acc, "..", rest, "\r\n"]
  end

  defp escape_line(line, acc) do
    [acc, line, "\r\n"]
  end

end
