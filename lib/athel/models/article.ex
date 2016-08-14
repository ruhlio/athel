defmodule Athel.Article do
  use Athel.Web, :model

  alias Athel.Group

  @primary_key {:message_id, :string, autogenerate: false}
  schema "articles" do
    field :from, :string
    field :subject, :string
    field :date, Timex.Ecto.DateTime
    field :content_type, :string
    #TODO: change to array
    field :body, :string

    many_to_many :groups, Group,
      join_through: "articles_to_groups",
      join_keys: [message_id: :message_id, group_id: :id]
    belongs_to :parent, __MODULE__,
      foreign_key: :parent_message_id,
      references: :message_id,
      type: :string

    timestamps()
  end

  @message_id_format ~r/^[a-zA-Z0-9$.]{2,128}@[a-zA-Z0-9.-]{2,63}$/

  def changeset(article, params \\ %{}) do
    article
    |> cast(params, [:message_id, :from, :subject, :date, :content_type, :body])
    |> cast_assoc(:groups)
    |> validate_format(:message_id, @message_id_format)
    |> cast_assoc(:parent, required: false)
    |> validate_required([:subject, :date, :content_type, :body])
    #TODO: validate content_type
  end

end
