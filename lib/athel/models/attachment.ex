defmodule Athel.Attachment do
  use Ecto.Schema

  import Ecto.Changeset
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
    max_attachment_size = Application.fetch_env!(:athel, Athel.Nntp)[:max_attachment_size]

    struct
    |> cast(params, [:content, :filename, :type])
    |> hash_changeset
    |> validate_required([:type, :hash, :content])
    |> validate_length(:content, max: max_attachment_size)
  end

  @spec hash_content(binary) :: {:ok, binary} | {:error, String.t}
  def hash_content(content) do
    Multihash.encode(:sha1, :crypto.hash(:sha, content))
  end

  defp hash_changeset(changeset = %Changeset{changes: changes}) do
    case changes[:content] do
      nil -> changeset
      content ->
        {:ok, hash} = hash_content(content)
        put_change(changeset, :hash, hash)
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
