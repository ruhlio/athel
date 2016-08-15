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
    field :body, {:array, :string}

    field :status, :string

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
    |> cast(params, [:message_id, :from, :subject, :date, :content_type, :body, :status])
    |> cast_assoc(:groups)
    |> validate_format(:message_id, @message_id_format)
    |> cast_assoc(:parent, required: false)
    |> validate_required([:subject, :date, :content_type, :body])
    |> validate_inclusion(:status, ["active", "banned"])
    #TODO: validate content_type
  end

  def get_headers(article) do
    %{"Newsgroups" => format_article_groups(article.groups),
      "Message-ID" => format_message_id(article.message_id),
      "References" => format_message_id(article.parent_message_id),
      "From" => article.from,
      "Subject" => article.subject,
      "Date" => format_date(article.date),
      "Content-Type" => article.content_type}
  end

  defp format_message_id(message_id) when is_nil(message_id) do
    nil
  end

  defp format_message_id(message_id) do
    [?<, message_id, ?>]
  end

  defp format_date(date) when is_nil(date) do
    nil
  end

  defp format_date(date) do
    Timex.format!(date, "%d %b %Y %H:%M:%S %z", :strftime)
  end

  defp format_article_groups(groups) do
    Enum.reduce(groups, :first, fn
      group, :first -> [group.name]
      group, acc -> [acc, ?,, group.name]
    end)
  end

end
