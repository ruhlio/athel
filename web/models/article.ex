defmodule Athel.Article do
  use Athel.Web, :model

  schema "articles" do
    field :from, :string
    field :subject, :string
    field :date, Timex.Ecto.DateTime
    field :reference, :string
    field :content_type, :string
    field :body, :string

    many_to_many :groups, Athel.Group,
      join_through: "articles_to_groups",
      on_delete: :delete_all

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:from, :subject, :date, :reference, :content_type, :body])
    |> cast_assoc(:groups)
    |> validate_required([:subject, :date, :content_type, :body])
  end
end
