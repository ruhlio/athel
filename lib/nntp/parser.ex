defmodule Athel.Nntp.Parser do

  @spec parse_code_line(iodata) :: {:ok, {integer, String.t}, iodata} | {:error, atom}
  def parse_code_line(input) do
    {code, rest} = code(input)
    {line, rest} = line(skip_whitespace(rest))
    {:ok, {code, line}, rest}
  catch
    {:invalid, type} -> {:error, type}
  end

  @digits '0123456789'

  defp code(input) do
    code(input, {[], 0})
  end

  defp code(<<digit, rest :: binary>>, {acc, count}) when digit in @digits do
    code(rest, {[acc, digit], count + 1})
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

  defp line(<<char, rest :: binary>>, acc) do
    line(rest, [acc, char])
  end

  defp line(_, _) do
    syntax_error(:line)
  end

  defp syntax_error(type) do
    throw {:invalid, type}
  end

end
