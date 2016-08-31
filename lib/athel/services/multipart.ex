defmodule Athel.Multipart do

  @type attachment :: %{type: String.t, filename: String.t, content: binary}

  @spec get_boundary(%{optional(String.t) => String.t}) :: {:ok, String.t | nil} | {:error, atom}
  def get_boundary(headers) do
    mime_version = headers["MIME-VERSION"]
    content_type = headers["CONTENT-TYPE"]
    case mime_version do
      "1.0" ->
        case content_type do
          {"multipart/mixed", %{"boundary" => boundary}} ->
            {:ok, boundary}
          {type, _} ->
            if is_multipart(type) do
              {:error, :unhandled_multipart_type}
            else
              {:ok, nil}
            end
          type ->
            if is_multipart(type) do
              {:error, :invalid_multipart_type}
            else
              {:ok, nil}
            end
        end
      nil -> {:ok, nil}
      _ ->
        {:error, :invalid_mime_version}
    end
  end

  @spec read_attachments(list(String.t), String.t) :: {:ok, list(attachment)} | {:error, atom}
  def read_attachments(lines, boundary) do
    attachments = lines |> parse(boundary) |> Enum.map(&cast_attachment/1)
    {:ok, attachments}
  catch
    reason -> {:error, reason}
  end

  defp is_multipart(content_type) when is_nil(content_type), do: false
  defp is_multipart(content_type), do: content_type =~ ~r/^multipart\//

  defp cast_attachment({headers, body}) do
    type = get_type(headers)
    filename = get_filename(headers)
    body = decode_body(headers, body)

    %{type: type, filename: filename, content: body}
  end

  defp get_type(headers) do
    case headers["CONTENT-TYPE"] do
      nil -> "text/plain"
      #todo: handle charset param
      {type, _params} -> type
      type -> type
    end
  end

  defp get_filename(headers) do
    case headers["CONTENT-DISPOSITION"] do
      nil ->
        nil
      {type, %{"filename" => filename}} when type in ["attachment", "form-data"] ->
        filename
      {_, _} ->
        throw :unhandled_content_disposition
      _ ->
        throw :unhandled_content_disposition
    end
  end

  defp decode_body(headers, body) do
    case headers["CONTENT-TRANSFER-ENCODING"] do
      nil ->
        body
      "base64" ->
        case body do
          [body] ->
            case Base.decode64(body) do
              {:ok, body} -> String.split(body, ~r/(\r\n)|\n|\r/)
              :error -> throw :invalid_encoding
            end
          _ -> throw :invalid_encoding
        end
      _ ->
        throw :unhandled_encoding
    end
  end

  defp parse(lines, boundary) do
    next_sigil = "--#{boundary}"
    terminator = "--#{boundary}--"

    # ignore comments (the top level body)
    case parse_body(lines, terminator, next_sigil, []) do
      {:continue, _, rest} ->
        parse_attachments(rest, terminator, next_sigil, [])
      {:terminate, _} ->
        []
    end
  end

  defp parse_body([], _, _, _) do
    throw :unterminated_body
  end

  defp parse_body([line | _], terminator, _, acc) when line == terminator do
    {:terminate, Enum.reverse(acc)}
  end

  defp parse_body([line | rest], _, next_sigil, acc) when line == next_sigil do
    {:continue, Enum.reverse(acc), rest}
  end

  defp parse_body([line | rest], terminator, next_sigil,  acc) do
    parse_body(rest, terminator, next_sigil, [line | acc])
  end

  defp parse_attachments([], _, _, _) do
    throw :unterminated_body
  end

  defp parse_attachments(lines, terminator, next_sigil, attachments) do
    case parse_attachment(lines, terminator, next_sigil) do
      {:continue, attachment, rest} ->
        parse_attachments(rest, terminator, next_sigil, [attachment | attachments])
      {:terminate, attachment} ->
        Enum.reverse([attachment | attachments])
    end
  end

  defp parse_attachment(lines, terminator, next_sigil) do
    {headers, rest} = parse_headers(lines, %{})
    case parse_body(rest, terminator, next_sigil, []) do
      {:continue, body, rest} ->
        {:continue, {headers, body}, rest}
      {:terminate, body} ->
        {:terminate, {headers, body}}
    end
  end

  defp parse_headers([], _) do
    throw :unterminated_headers
  end

  defp parse_headers([line | rest], headers) when line == "" do
    {headers, rest}
  end

  defp parse_headers([line | rest], headers) do
    case Regex.run ~r/^([a-z0-9.-]+):\s*([^;]+)(;\s*\w+=".*")*/i, line do
      nil ->
        if Enum.empty?(headers) do
          {%{}, [line | rest]}
        else
          throw :invalid_header
        end
      [_, name, value] ->
        next_headers = Map.put(headers, name |> String.upcase, value |> String.trim)
        parse_headers(rest, next_headers)
      [_, name, value, raw_params] ->
        params = parse_header_params(raw_params)
        next_headers = Map.put(headers, name |> String.upcase, {value |> String.trim, params})
        parse_headers(rest, next_headers)
    end
  end

  # re-parses input, but regex can't return an array of matches from a subgroup
  defp parse_header_params(raw_params) do
    raw_params
    |> String.split(";")
    # skip first blank entry (String.split(";con;queso") == ["", "con", "queso"])
    |> Stream.drop(1)
    |> Enum.reduce(%{}, fn raw_param, params ->
      # input already validated in parse_headers()
      [_, name, value] = Regex.run ~r/^\s*(\w+)="(.*)"/, raw_param
      Map.put(params, name, value)
    end)
  end

end
