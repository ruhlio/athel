defmodule Athel.Group do
  use Athel.Web, :model

  schema "groups" do
    field :name, :string
    field :low_watermark, :integer
    field :high_watermark, :integer
    field :status, :string

    many_to_many :articles, Athel.Article,
      join_through: "articles_to_groups",
      on_delete: :delete_all

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :low_watermark, :high_watermark, :status])
    |> validate_required([:name, :low_watermark, :high_watermark, :status])
    |> validate_format(:group, ~r/^[a-zA-Z0-9_.-]{1,128}$/)
    |> unique_constraint(:group)
    |> validate_inclusion(:status, ["y", "n", "m"])
  end
end
