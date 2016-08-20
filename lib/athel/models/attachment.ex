defmodule Athel.Attachment do
  use Athel.Web, :model

  alias Ecto.Changeset
  alias Athel.Article

  schema "attachments" do
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
    |> cast(params, [:type, :content])
    |> hash_content
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

end
