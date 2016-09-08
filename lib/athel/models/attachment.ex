defmodule Athel.Attachment do
  use Athel.Web, :model

  alias Ecto.Changeset
  alias Athel.Article

  schema "attachments" do
    field :filename, :string
    field :type, :string
    field :hash, :binary
    field :content, :binary

    many_to_many :article, Article,
      join_through: "attachments_to_articles",
      join_keys: [attachment_id: :id, message_id: :message_id]

    timestamps()
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:content])
    |> hash_content
    |> determine_type
    |> validate_required([:type, :hash, :content])
  end

  defp hash_content(changeset = %Changeset{changes: changes}) do
    case changes[:content] do
      nil -> changeset
      content ->
        {:ok, hash} = Multihash.encode(:sha1, :crypto.hash(:sha, content))
        put_change(changeset, :hash, hash)
    end
  end

  defp determine_type(changeset = %Changeset{changes: changes}) do
    case changes[:content] do
      nil -> add_error(changeset, :type, "unrecognized type of content")
      content ->
        case :emagic.from_buffer(content) do
          {:ok, type} ->
            put_change(changeset, :type, type)
          {:error, reason} ->
            add_error(changeset, :type, to_string(reason))
        end
    end
  end

end

defimpl Athel.Nntp.Formattable, for: Athel.Attachment do
  alias Athel.Nntp.Formattable

  def format(attachment) do
    headers =
      %{"Content-Type" => attachment.type,
        "Content-Transfer-Encoding" => "base64"}
    |> add_disposition_header(attachment.filename)

    [Formattable.format(headers), Base.encode64(attachment.content), "\r\n"]
  end

  defp add_disposition_header(headers, nil) do
    headers
  end

  defp add_disposition_header(headers, filename) do
    Map.put(headers,
      "Content-Disposition", "attachment, filename=\"#{filename}\"")
  end

end
