defmodule Athel.Nntp.Parser do

  @type parse_result(parsed) :: {:ok, parsed, iodata} | {:error, atom} | :need_more

  @spec parse_code_line(iodata) :: parse_result({integer, String.t})
  def parse_code_line(input) do
    {code, rest} = code(input)
    {line, rest} = line(skip_whitespace(rest))
    {:ok, {code, line}, rest}
  catch
    e -> e
  end

  @spec parse_multiline(iodata) :: parse_result(list(String.t))
  def parse_multiline(input) do
    {lines, rest} = multiline(input, [])
    {:ok, lines, rest}
  catch
    e -> e
  end

  @spec parse_headers(iodata) :: parse_result(%{optional(String.t) => String.t})
  def parse_headers(input) do
    {headers, rest} = headers(input, %{})
    {:ok, headers, rest}
  catch
    e -> e
  end

  @spec parse_command(iodata) :: parse_result({String.t, list(String.t)})
  def parse_command(input) do
    {name, arguments, rest} = command(IO.iodata_to_binary(input))
    {:ok, {name, arguments}, rest}
  catch
    e -> e
  end

  @digits '0123456789'

  defp code(input) do
    code(input, {[], 0})
  end

  defp code(<<digit, rest :: binary>>, {acc, count}) when digit in @digits do
    code(rest, {[acc, digit], count + 1})
  end

  defp code("", {_, count}) when count < 3 do
    need_more()
  end

  defp code(next, state) do
    end_code(state, next)
  end

  defp end_code({acc, 3}, rest) do
    {IO.iodata_to_binary(acc) |> String.to_integer, rest}
  end

  defp end_code(_, _) do
    syntax_error(:code)
  end

  @whitespace '\s\t'

  defp skip_whitespace(<<char :: utf8, rest :: binary>>) when char in @whitespace do
    rest
  end

  defp skip_whitespace(string) do
    string
  end

  defp line(input) do
    line(input, [])
  end

  defp line(<<"\r\n", rest :: binary>>, acc)  do
    {IO.iodata_to_binary(acc), rest}
  end

  defp line(<<?\r, next>>, _) when next != ?\n do
    syntax_error(:line)
  end

  defp line(<<?\n, _ :: binary>>, _) do
    syntax_error(:line)
  end

  defp line(<<char, rest :: binary>>, acc) do
    line(rest, [acc, char])
  end

  defp line("", _) do
    need_more()
  end

  defp line(_, _) do
    syntax_error(:line)
  end

  defp multiline(<<".\r\n", rest :: binary>>, acc) do
    {Enum.reverse(acc), rest}
  end

  defp multiline("", _) do
    need_more()
  end

  defp multiline(<<"..", rest :: binary>>, acc) do
    # i believe binary concats are slower, but how often does escaping really happen?
    {line, rest} = line("." <> rest)
    multiline(rest, [line | acc])
  end

  defp multiline(<<".", next, _ :: binary>>, _) when next != "\r" and next != "." do
    syntax_error(:multiline)
  end

  defp multiline(input, acc) do
    {line, rest} = line(input)
    multiline(rest,  [line | acc])
  end

  defp headers(<<"\r\n", rest :: binary>>, acc) do
    {acc, rest}
  end

  defp headers("", _) do
    need_more()
  end

  defp headers(input, acc) do
    {name, rest} = header_name(input, [])
    {value, rest} = line(skip_whitespace(rest))
    headers(rest, Map.put(acc, name, value))
  end

  defp header_name(<<":", rest :: binary>>, acc) do
    {IO.iodata_to_binary(acc), rest}
  end

  defp header_name(<<next, rest :: binary>>, acc) do
    #todo: `not in` guard?
    if (next in @whitespace or next in '\r\n'), do: syntax_error(:header_name)
    header_name(rest, [acc, next])
  end

  defp header_name("", _) do
    need_more()
  end

  defp command(input) do
    command(input, {[], [], []})
  end

  # end of command
  defp command(<<"\r\n", rest :: binary>>, {command, arguments, acc}) do
    if Enum.empty? command do
      if Enum.empty? acc do
        syntax_error(:command)
      else
        end_command(acc, arguments, rest)
      end
    else
      end_command(command, [acc | arguments], rest)
    end
  end

  # need more
  defp command("", _) do
    need_more()
  end

  # end of command name
  defp command(<<next, rest :: binary>>, {[], [], acc}) when next in @whitespace do
    command(rest, {acc, [], []})
  end

  # reading command name
  defp command(<<next, rest :: binary>>, {[], [], acc}) do
    command(rest, {[], [], [acc, next]})
  end

  # end of argument
  defp command(<<next, rest :: binary>>, {command, arguments, acc}) when next in @whitespace do
    command(rest, {command, [acc | arguments], []})
  end

  # reading argument
  defp command(<<next, rest :: binary>>, {command, arguments, acc}) do
    command(rest, {command, arguments, [acc, next]})
  end

  defp end_command(command, arguments, rest) do
    arguments = Enum.map(arguments, &IO.iodata_to_binary/1) |> Enum.reverse
    {IO.iodata_to_binary(command), arguments, rest}
  end

  defp need_more() do
    throw :need_more
  end

  defp syntax_error(type) do
    throw {:error, type}
  end

end
