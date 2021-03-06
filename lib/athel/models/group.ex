defmodule Athel.Group do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:name, :string, autogenerate: false}
  schema "groups" do
    field :description, :string
    field :low_watermark, :integer
    field :high_watermark, :integer
    field :status, :string

    many_to_many :articles, Athel.Article,
      join_through: "articles_to_groups",
      join_keys: [group_name: :name, message_id: :message_id]
    many_to_many :article_search_indexes, Athel.ArticleSearchIndex,
      join_through: "articles_to_groups",
      join_keys: [group_name: :name, message_id: :message_id]

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :description, :low_watermark, :high_watermark, :status])
    |> validate_required([:name, :low_watermark, :high_watermark, :status])
    |> validate_format(:name, ~r/^[a-zA-Z0-9_.-]{1,128}$/)
    |> unique_constraint(:name, name: "groups_pkey")
    |> validate_inclusion(:status, ["y", "n", "m"])
  end
end
