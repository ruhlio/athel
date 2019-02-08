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

  @whitespace ' \t'

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

  # previous is for handling multiline headers
  # :need_more is only handled at the top level (via reading in a whole line at a time) for simplicity
  # initialize
  defp headers(input, nil) do
    headers(input, %{
          line_acc: [],
          headers: %{},
          header_name: nil,
          param_name_acc: []})
  end
  defp headers("", state) do
    need_more(state)
  end
  # parse
  defp headers(input, state) do
    {line, rest} =
      try do
        line(input, state.line_acc)
      catch
        {:need_more, next_line_acc} -> need_more(%{state | line_acc: next_line_acc})
      end

    cond do
      # empty line signifies end of headers
      "" == line -> {state.headers, rest}
      # multiline header
      line =~ ~r/^\s+/ ->
          case state.header_name do
            nil -> syntax_error(:multiline_header)
            header_name ->
              # resuming header value parse
              new_headers = Map.update(state.headers, header_name, "",
                &merge_header_lines(&1, line, state))
              headers(rest, %{state | line_acc: [], headers: new_headers})
          end
      true ->
          {name, rest_value} = header_name(line, [])
          named_state = %{state | header_name: name, param_name_acc: []}
          value = header_value(skip_whitespace(rest_value), [], named_state)
          new_headers = Map.update(state.headers, name, value, &merge_headers(&1, value))

          headers(rest, %{named_state | line_acc: [], headers: new_headers})
    end
  end

  # values are inserted backwards while merging

  defp merge_header_lines(prev, line, state) when is_list(prev) do
    [last | rest] = prev
    [merge_header_lines(last, line, state) | rest]
  end
  defp merge_header_lines(%{value: value, params: params}, line, state) do
    next_params = header_params(line, params, state)
    %{value: value, params: next_params}
  catch
    {:need_more, {new_params, param_name_acc}} ->
      handle_incomplete_params_parse(state, value, Map.merge(params, new_params), param_name_acc)
  end
  defp merge_header_lines(prev, line, state) do
    next = header_value(line, [], state)
    "#{prev} #{next}"
  end

  defp handle_incomplete_params_parse(state, header_value, params, param_name_acc) do
    new_headers = Map.put(state.headers, state.header_name, %{value: header_value, params: params})
    need_more(%{state | headers: new_headers, param_name_acc: param_name_acc})
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

  @param_headers ["CONTENT-TYPE", "CONTENT-DISPOSITION"]

  # termination
  defp header_value("", acc, _), do: terminate_header_value(acc)
  # start of params
  defp header_value(<<";", rest :: binary>>, acc, state = %{header_name: header_name})
  when header_name in @param_headers do
    params = header_params(rest, %{}, state)
    %{value: terminate_header_value(acc), params: params}
  catch
    {:need_more, {params, param_name_acc}} ->
      handle_incomplete_params_parse(state, terminate_header_value(acc), params, param_name_acc)
  end
  # parse
  defp header_value(<<char, rest :: binary>>, acc, state) do
    header_value(rest, [acc, char], state)
  end

  defp terminate_header_value(acc) do
    acc |> IO.iodata_to_binary |> String.trim
  end

  # termination
  defp header_params("", params, _), do: params
  # parse
  defp header_params(input, params, state) do
    {param_name, value_input} = try do
      header_param_name(input, state.param_name_acc)
    catch
      {:need_more, param_name_acc} -> need_more({params, param_name_acc})
    end
    {param_value, next_param_input} = header_param_value(value_input, {[], false})
    cleared_state = %{state | param_name_acc: []}
    header_params(next_param_input, params |> Map.put(param_name, param_value), cleared_state)
  end

  # haven't found "=" separator
  defp header_param_name("", acc) do
    need_more(acc)
  end
  # eat leading whitespace
  defp header_param_name(<<char, rest :: binary>>, acc) when char in @whitespace do
    header_param_name(rest, acc)
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
