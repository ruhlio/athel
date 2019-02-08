defmodule Athel.Multipart do
  alias Athel.Nntp.Parser

  @type attachment :: %{
    type: String.t,
    filename: String.t,
    params: %{optional(atom) => any},
    content: binary,
    attachments: list(attachment)}

  @spec read_attachments(%{optional(String.t) => String.t}, list(String.t)) :: {:ok, list(attachment)} | {:error, atom}
  def read_attachments(headers, body) do
    mime_version = headers["MIME-VERSION"]

    case mime_version do
      "1.0" ->
        check_multipart_type(headers, "multipart/mixed", fn boundary ->
          {raw_attachments, _} = parse(body, boundary)
          attachments = Enum.map(raw_attachments, &cast_attachment/1)
          {:ok, attachments}
        end)
      nil ->
        {:ok, nil}
      _ ->
        {:error, :invalid_mime_version}
    end
  catch
    reason -> {:error, reason}
  end

  defp check_multipart_type(headers, valid_type, process) do
    content_type = headers["CONTENT-TYPE"]

    case content_type do
      %{value: ^valid_type, params: %{"BOUNDARY" => boundary}} ->
        process.(boundary)
      %{value: type} ->
        if is_multipart(type) do
          fail(:unhandled_multipart_type)
        else
          {:ok, nil}
        end
      type ->
        if is_multipart(type) do
          fail(:invalid_multipart_type)
        else
          {:ok, nil}
        end
    end
  end

  defp is_multipart(content_type) when is_nil(content_type), do: false
  defp is_multipart(content_type) do
    content_type =~ ~r/^multipart\//
  end

  defp cast_attachment({
    %{"CONTENT-TYPE" => %{value: "multipart/signed",
                          params: %{"MICALG" => micalg, "PROTOCOL" => protocol}}},
    _,
    [{headers, body, []}, {_, signature, []}]})
    do
    stripped_signature = strip_signature(signature)

    %{type: "multipart/signed",
      params: %{micalg: micalg, protocol: protocol, signature: stripped_signature},
      filename: nil,
      content: decode_body(headers, body),
      attachments: []}
  end
  defp cast_attachment({%{"CONTENT-TYPE" => %{value: "multipart/signed"}}, _, _}) do
    fail(:invalid_multipart_signed_type)
  end
  defp cast_attachment({headers, body, attachments}) do
    %{type: get_type(headers),
      params: %{},
      filename: get_filename(headers),
      content: decode_body(headers, body),
      attachments: attachments}
  end

  defp get_type(headers) do
    case headers["CONTENT-TYPE"] do
      nil -> "text/plain"
      %{value: type} -> type
      type -> type
    end
  end

  defp get_filename(headers) do
    case headers["CONTENT-DISPOSITION"] do
      nil ->
        nil
      %{value: type, params: %{"FILENAME" => filename}} when type in ["attachment", "form-data"] ->
        filename
      content_disposition when is_map(content_disposition) ->
        fail(:unhandled_content_disposition)
      _ ->
        nil
    end
  end

  defp decode_body(headers, body) do
    encoding = headers |> Map.get("CONTENT-TRANSFER-ENCODING", "") |> String.upcase

    case encoding do
      "" ->
        body
      ignore when ignore in ["7BIT", "8BIT", "BINARY", "QUOTED-PRINTABLE"] ->
        body
      "BASE64" ->
        deserialized = body
        |> Enum.join("")
        |> Base.decode64(body)
        case deserialized do
          {:ok, body} -> body
          :error -> fail(:invalid_transfer_encoding)
        end
      _ ->
        fail(:unhandled_transfer_encoding)
    end
  end

  defp strip_signature(["-----BEGIN PGP SIGNATURE-----" | rest]) do
    strip_signature(rest, [])
  end
  defp strip_signature(_), do: fail(:invalid_signature)
  defp strip_signature(["-----END PGP SIGNATURE-----" | _], acc) do
    Enum.reverse(acc)
  end
  defp strip_signature([next | rest], acc) do
    strip_signature(rest, [next | acc])
  end
  defp strip_signature(_, _), do: throw fail(:invalid_signature)

  ### Parsing

  defp parse(lines, boundary) do
    next_sigil = "--#{boundary}"
    terminator = "--#{boundary}--"

    # ignore comments (the top level body)
    case parse_body(lines, terminator, next_sigil, []) do
      {:continue, _, rest} ->
        parse_attachments(rest, terminator, next_sigil, [])
      {:terminate, _, _} ->
        {[], nil} 
    end
  end

  defp parse_nested(headers, body) do
    check_multipart_type(headers, "multipart/signed", fn boundary ->
      parse(body, boundary)
    end)
  end

  defp parse_body([], _, _, _) do
    fail(:unterminated_body)
  end
  defp parse_body([line | rest], terminator, _, acc) when line == terminator do
    {:terminate, Enum.reverse(acc), rest}
  end
  defp parse_body([line | rest], _, next_sigil, acc) when line == next_sigil do
    {:continue, Enum.reverse(acc), rest}
  end
  defp parse_body([line | rest], terminator, next_sigil,  acc) do
    parse_body(rest, terminator, next_sigil, [line | acc])
  end

  defp parse_attachments([], _, _, _) do
    fail(:unterminated_body)
  end
  defp parse_attachments(lines, terminator, next_sigil, attachments) do
    case parse_attachment(lines, terminator, next_sigil) do
      {:continue, attachment, rest} ->
        parse_attachments(rest, terminator, next_sigil, [attachment | attachments])
      {:terminate, attachment, rest} ->
        {Enum.reverse([attachment | attachments]), rest}
    end
  end

  defp parse_attachment(lines, terminator, next_sigil) do
    {headers, rest} = read_headers(lines)

    case parse_nested(headers, rest) do
      {:ok, nil} ->
        case parse_body(rest, terminator, next_sigil, []) do
          {:continue, body, rest} ->
            {:continue, {headers, body, []}, rest}
          {:terminate, body, rest} ->
            {:terminate, {headers, body, []}, rest}
        end
      {attachments, rest} ->
        # eat deadspace until beginning of next attachment
        case Enum.split_while(rest, &(&1 != next_sigil)) do
          {_deadspace, []} ->
            {:terminate, {headers, [], attachments}, []}
          {_deadspace, [_sigil]} ->
            throw :unterminated_body
          {_deadspace, [_sigil | rest]} ->
            {:continue, {headers, [], attachments}, rest}
        end
    end
  end

  defp read_headers(lines, state \\ nil)
  defp read_headers([line | lines], state) do
    case Parser.parse_headers("#{line}\r\n", state) do
      {:ok, headers, _} -> {headers, lines}
      {:error, reason} -> fail(reason)
      {:need_more, state} -> read_headers(lines, state)
    end
  end
  defp read_headers([], _), do: fail(:unterminated_headers)

  defp fail(reason) do
    throw reason
  end

end
