defmodule Athel.Nntp.Parser do

  @type parse_result(parsed) :: {:ok, parsed, iodata} | {:error, atom} | {:need_more, any()}

  @spec parse_code_line(iodata) :: parse_result({integer, String.t})
  def parse_code_line(input, state \\ nil) do
    {result, rest} = input |> IO.iodata_to_binary |> code_line(state)
    {:ok, result, rest}
  catch
    e -> e
  end

  @spec parse_multiline(iodata, list(String.t)) :: parse_result(list(String.t))
  def parse_multiline(input, state \\ nil) do
    {lines, rest} = input |> IO.iodata_to_binary |> multiline(state)
    {:ok, lines, rest}
  catch
    e -> e
  end

  @spec parse_headers(iodata) :: parse_result(%{optional(String.t) => String.t | list(String.t)})
  def parse_headers(input, state \\ nil) do
    {headers, rest} = input |> IO.iodata_to_binary |> headers(state)
    {:ok, headers, rest}
  catch
    e -> e
  end

  @spec parse_command(iodata) :: parse_result({String.t, list(String.t)})
  def parse_command(input, state \\ nil) do
    {name, arguments, rest} = input |> IO.iodata_to_binary |> command(state)
    {:ok, {name, arguments}, rest}
  catch
    e -> e
  end

  @digits '0123456789'

  defp code(input, nil) do
    code(input, {[], 0})
  end
  defp code(<<digit, rest :: binary>>, {acc, count}) when digit in @digits do
    code(rest, {[acc, digit], count + 1})
  end
  defp code("", {acc, count}) when count < 3 do
    need_more({acc, count})
  end
  defp code(next, state) do
    end_code(state, next)
  end

  defp end_code({acc, 3}, rest) do
    {acc |> IO.iodata_to_binary |> String.to_integer, rest}
  end
  defp end_code(_in, _acc) do
    syntax_error(:code)
  end

  @whitespace '\s\t'

  defp skip_whitespace(<<char :: utf8, rest :: binary>>) when char in @whitespace do
    rest
  end
  defp skip_whitespace(string) do
    string
  end

  defp line("", acc) do
    need_more(acc)
  end
  defp line(<<"\r\n", rest :: binary>>, acc)  do
    {IO.iodata_to_binary(acc), rest}
  end
  # newline split across reads
  defp line(<<?\r>>, acc) do
    need_more([acc, ?\r])
  end
  # if there is more after \r, enforce \n
  defp line(<<?\r, next>>, _) when next != ?\n do
    syntax_error(:line)
  end
  # end of newline split across reads. Read backwards to confirm \r preceded
  defp line(<<?\n, rest :: binary>>, acc) do
    [head | tail] = acc
    case tail do
      '\r' -> {IO.iodata_to_binary(head), rest}
      _ -> syntax_error(:line)
    end
  end
  defp line(<<char, rest :: binary>>, acc) do
    line(rest, [acc, char])
  end
  defp line(_, _) do
    syntax_error(:line)
  end

  # code_line state is {:code, current_code} | {:line, current_line, code}
  # resume
  defp code_line(input, {:code, acc}) do
    code_line(input, acc)
  end
  defp code_line(input, {:line, acc, code}) do
    end_code_line(input, acc, code)
  end
  # parse
  defp code_line(input, acc) do
    {code, rest} = try do
      code(input, acc)
    catch
      {:need_more, acc} -> need_more({:code, acc})
    end

    end_code_line(rest, [], code)
  end

  defp end_code_line(input, acc, code) do
    {line, rest} =
      try do
        input |> skip_whitespace |> line(acc)
      catch
        {:need_more, acc} -> need_more({:line, acc, code})
      end
    {{code, line}, rest}
  end

  # multiline state is {current_line, lines}
  # first iteration
  defp multiline(input, nil) do
    multiline(input, {[], []})
  end
  # no input
  defp multiline("", state) do
    need_more(state)
  end
  # parsing
  defp multiline(input, {line_acc, acc}) do
    {line, rest} =
      try do
        line(input, line_acc)
      catch
        {:need_more, next_line_acc} -> need_more({next_line_acc, acc})
      end

    #IO.puts "at #{inspect(line)} with #{inspect rest} after #{inspect input}"
    case line do
      # escaped leading .
      <<"..", line_rest :: binary>> ->
        escaped_line = "." <> line_rest
        multiline(rest, {[], [escaped_line | acc]})
      # termination
      <<".">> -> {Enum.reverse(acc), rest}
      # leading . that neither terminated nor was escaped is invalid
      <<".", _ :: binary>> ->
        syntax_error(:multiline)
      # else keep reading
      line -> multiline(rest, {[], [line | acc]})
    end
  end

  # headers state is {current_line, headers, previous_header}
  # previous header is for handling multiline headers
  # :need_more is only handled at the top level (via reading in a whole line at a time) for simplicity
  # initialize
  defp headers(input, nil) do
    headers(input, {[], %{}, nil})
  end
  defp headers("", state) do
    need_more(state)
  end
  # parse
  defp headers(input, {line_acc, acc, prev_header}) do
    {line, rest} =
      try do
        line(input, line_acc)
      catch
        {:need_more, next_line_acc} -> need_more({next_line_acc, acc, prev_header})
      end

    cond do
      # empty line signifies end of headers
      "" == line -> {acc, rest}
      # multiline header. Just slap onto previous header's value with a space
      line =~ ~r/^\s+/ ->
          case prev_header do
            nil -> syntax_error(:multiline_header)
            _ ->
              new_acc = Map.update(acc, prev_header, "",
                &merge_header_lines(&1, line, prev_header))
              headers(rest, {[], new_acc, prev_header})
          end
      true ->
          {name, rest_value} = header_name(line, [])
          value = header_value(skip_whitespace(rest_value), {[], name})
          new_acc = Map.update(acc, name, value, &merge_headers(&1, value))
          headers(rest, {[], new_acc, name})
    end
  end

  # values are inserted backwards while merging
  # currently doesn't handle headers with params

  defp merge_header_lines(prev, line, name) when is_list(prev) do
    [last | rest] = prev
    [merge_header_lines(last, line, name) | rest]
  end
  defp merge_header_lines({value, params}, line, _) do
    next_params = header_params(line, params)
    {value, next_params}
  end
  defp merge_header_lines(prev, line, name) do
    next = header_value(line, {[], name}) |> String.trim_leading
    "#{prev} #{next}"
  end

  defp merge_headers(prev, new) when is_list(prev) do
    [new | prev]
  end
  defp merge_headers(prev, new) do
    [new, prev]
  end

  # hit EOL without ":" separator
  defp header_name("", _), do: syntax_error(:header_name)
  # termination
  defp header_name(<<":", rest :: binary>>, acc) do
    {acc |> IO.iodata_to_binary |> String.upcase, rest}
  end
  # no whitespace in header names
  defp header_name(<<next, _ :: binary>>, _) when next in @whitespace, do: syntax_error(:header_name)
  # parse
  defp header_name(<<next, rest :: binary>>, acc) do
    header_name(rest, [acc, next])
  end

  @param_headers ["CONTENT-TYPE"]

  # header_value state is {current_value, header_name}
  # termination
  defp header_value("", {acc, _}) do
    acc |> IO.iodata_to_binary
  end
  # start of params
  defp header_value(<<";", rest :: binary>>, {acc, header_name}) when header_name in @param_headers do
    params = header_params(rest, %{})
    {acc |> IO.iodata_to_binary, params}
  end
  # parse
  defp header_value(<<char, rest :: binary>>, {acc, header_name}) do
    header_value(rest, {[acc, char], header_name})
  end

  # termination
  defp header_params("", params), do: params
  # parse
  defp header_params(input, params) do
    {param_name, rest} = header_param_name(input, [])
    {param_value, rest} = header_param_value(rest, {[], false})
    header_params(rest, params |> Map.put(param_name, param_value))
  end

  # never found "=" separator
  defp header_param_name("", _), do: syntax_error(:header_param_name)
  # eat leading whitespace
  defp header_param_name(<<char, rest :: binary>>, []) when char in ' \t' do
    header_param_name(rest, [])
  end
  # termination
  defp header_param_name(<<"=", rest :: binary>>, acc) do
    {acc |> IO.iodata_to_binary |> String.upcase, rest}
  end
  # parse
  defp header_param_name(<<char, rest :: binary>>, acc) do
    header_param_name(rest, [acc, char])
  end

  # termination
  defp header_param_value("", {acc, _}) do
    {acc |> IO.iodata_to_binary, ""}
  end
  defp header_param_value(<<";", rest :: binary>>, {acc, _}) do
    {acc |> IO.iodata_to_binary, rest}
  end
  # handle boundary="commadelimited"
  defp header_param_value(<<"\"", rest :: binary>>, {acc, delimited}) do
    cond do
      delimited ->
        case Regex.run ~r/^( |\t)*(;?(.*))/s, rest do
          nil -> syntax_error(:header_param_value)
          [_, _, _, rest2] ->
            {acc |> IO.iodata_to_binary, rest2}
        end
      IO.iodata_to_binary(acc) =~ ~r/^\s*$/ ->
        header_param_value(rest, {[], true})
      not delimited ->
        header_param_value(rest, {[acc, "\""], false})
    end
  end
  # parse
  defp header_param_value(<<char, rest :: binary>>, {acc, delimited}) do
    header_param_value(rest, {[acc, char], delimited})
  end

  # command state is {command_name, arguments, current_identifier}
  # initialize
  defp command(input, nil) do
    command(input, {[], [], []})
  end
  # end of command
  defp command(<<"\r\n", rest :: binary>>, state) do
    end_command(state, rest)
  end
  # newline split across reads
  defp command(<<?\r>>, {name, arguments, acc}) do
    need_more({name, arguments, [acc, ?\r]})
  end
  # if there is more after \r, enforce \n
  defp command(<<?\r, next>>, _) when next != ?\n do
    syntax_error(:command)
  end
  # end of newline split across reads. Read backwards to confirm \r preceded
  defp command(<<?\n, rest :: binary>>, {command, arguments, acc}) do
    [head | tail] = acc
    case tail do
      '\r' -> end_command({command, arguments, head}, rest)
      _ -> syntax_error(:command)
    end
  end
  # need more
  defp command("", acc) do
    need_more(acc)
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
  defp command(<<next, rest :: binary>>, {name, arguments, acc}) when next in @whitespace do
    command(rest, {name, [acc | arguments], []})
  end
  # reading argument
  defp command(<<next, rest :: binary>>, {name, arguments, acc}) do
    command(rest, {name, arguments, [acc, next]})
  end

  defp end_command({name, arguments, acc}, rest) do
    {name, arguments} =
    if Enum.empty? name do
      if Enum.empty? acc do
        syntax_error(:command)
      else
        {acc, []}
      end
    else
      if Enum.empty? acc do
        {name, arguments}
      else
        {name, [acc | arguments]}
      end
    end

    name = name |> IO.iodata_to_binary |> String.upcase
    arguments = arguments |> Enum.map(&IO.iodata_to_binary/1) |> Enum.reverse
    {name, arguments, rest}
  end

  defp need_more(state) do
    throw {:need_more, state}
  end

  defp syntax_error(type) do
    throw {:error, type}
  end

end
