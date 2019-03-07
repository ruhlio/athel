defmodule Athel.ArticleSearchIndex do
  use Ecto.Schema

  @primary_key {:message_id, :string, autogenerate: false}
  schema "article_search_index" do
    field :from, :string
    field :subject, :string
    field :date, :utc_datetime
    field :status, :string
    field :document, {:array, :map}

    many_to_many :groups, Athel.Group,
      join_through: "articles_to_groups",
      join_keys: [message_id: :message_id, group_id: :id]
  end

  def update_view() do
    Ecto.Adapters.SQL.query!(Athel.Repo, "REFRESH MATERIALIZED VIEW article_search_index")
  end
end
