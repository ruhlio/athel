defmodule Athel.Multipart do

  @type attachment :: %{type: String.t, filename: String.t, content: binary}

  @spec get_boundary(%{optional(String.t) => String.t}) :: {:ok, String.t} | {:error, atom}
  def get_boundary(headers) do
    mime_version = headers["MIME-VERSION"]
    content_type = headers["CONTENT-TYPE"]
    case mime_version do
      "1.0" ->
        case content_type do
          {"multipart/mixed", %{"boundary" => boundary}} -> {:ok, boundary}
          _ -> {:error, :unhandled_multipart_type}
        end
      _ ->
        {:error, :invalid_mime_version}
    end
  end

  @spec read_attachments(list(String.t), String.t) :: {:ok, attachment} | {:error, atom}
  def read_attachments(lines, boundary) do
  end

end
