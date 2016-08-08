defmodule Athel.Group do
  use Athel.Web, :model

  schema "groups" do
    field :name, :string
    field :description, :string
    field :low_watermark, :integer
    field :high_watermark, :integer
    field :status, :string

    many_to_many :articles, Athel.Article,
      join_through: "articles_to_groups",
      join_keys: [group_id: :id, message_id: :message_id]

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
    |> unique_constraint(:name)
    |> validate_inclusion(:status, ["y", "n", "m"])
  end
end
