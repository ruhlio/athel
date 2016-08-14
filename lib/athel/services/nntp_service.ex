defmodule Athel.NntpService do
  import Ecto.Query
  alias Ecto.{Changeset, UUID}
  alias Athel.{Repo, Group, Article}

  @type changeset_params :: %{optional(binary) => term} | %{optional(atom) => term}
  @type headers :: %{optional(String.t) => String.t}
  @type new_article_result :: {:ok, Article.t} | {:error, Changeset.t}
  @type indexed_article :: {non_neg_integer, Article.t}

  @spec get_groups() :: list(Group.t)
  def get_groups do
    Repo.all(from g in Group, order_by: :name)
  end

  @spec get_group(String.t) :: Group.t | nil
  def get_group(group_name) do
    Repo.get_by(Group, name: group_name)
  end

  @spec get_article(String.t) :: Article.t | nil
  def get_article(message_id) do
    Repo.one(from a in Article,
      where: a.message_id == ^message_id and a.status == "active")
  end

  @spec get_article_by_index(Group.t, integer) :: indexed_article | nil
  def get_article_by_index(group, index) do
    group |> base_by_index(index) |> limit(1) |> Repo.one
  end

  @spec get_article_by_index(Group.t, integer, :infinity) :: list(indexed_article)
  def get_article_by_index(group, lower_bound, :infinity) do
    group |> base_by_index(lower_bound) |> Repo.all
  end

  @spec get_article_by_index(Group.t, integer, integer) :: list(indexed_article)
  def get_article_by_index(group, lower_bound, upper_bound) do
    count = max(upper_bound - lower_bound, 0)
    group |> base_by_index(lower_bound) |> limit(^count) |> Repo.all
  end

  defp base_by_index(group, lower_bound) do
    lower_bound = max(group.low_watermark, lower_bound)
    Article
    |> where(status: "active")
    |> offset(^lower_bound)
    |> order_by(:date)
    |> select([a, i], {i.index, a})
    # subqueries with fragments in the `select` not supported, whole query must
    # be a fragment to be joined on
    # make `row_number()` zero-indexed to match up with `offset`
    #see: https://github.com/elixir-ecto/ecto/issues/1416
    |> join(:inner, [a], i in fragment("""
    SELECT (row_number() OVER (ORDER BY a.date) - 1) as index,
           a.message_id as message_id
    FROM articles a
    JOIN articles_to_groups a2g ON a2g.message_id = a.message_id
    JOIN groups g ON g.id = a2g.group_id AND g.name = ?
    """, ^group.name), i.message_id == a.message_id)
  end

  @spec post_article(headers, list(String.t)) :: new_article_result
  def post_article(headers, body) do
    params = %{
      message_id: generate_message_id(),
      from: headers["From"],
      subject: headers["Subject"],
      date: Timex.now(),
      content_type: headers["Content-Type"],
      body: Enum.join(body, "\n"),
      status: "active"
    }

    group_names = headers
    |> Map.get("Newsgroups", "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    groups = Repo.all(from g in Group, where: g.name in ^group_names)
    parent_message_id = headers["References"]
    parent = unless is_nil(parent_message_id) do
      Repo.get(Article,  parent_message_id)
    end
    changeset = Article.changeset(%Article{}, params)

    changeset = cond do
      length(groups) == 0 || length(group_names) != length(groups) ->
        Changeset.add_error(changeset, :groups, "is invalid")
      Enum.any?(groups, &(&1.status == "n")) ->
        #TODO: move this to the base changeset? or the group changeset?
        Changeset.add_error(changeset, :groups, "doesn't allow posting")
      true ->
        Changeset.put_assoc(changeset, :groups, groups)
    end

    changeset = if is_nil(parent) && !is_nil(parent_message_id) do
      Changeset.add_error(changeset, :parent, "is invalid")
    else
      Changeset.put_assoc(changeset, :parent, parent)
    end

    Repo.insert(changeset)
  end

  @spec new_topic(list(Group.t), changeset_params) :: new_article_result
  def new_topic(groups, params) do
    params = Map.merge(params,
      %{message_id: generate_message_id(),
        parent: nil,
        date: Timex.now()})

    %Article{}
    |> Article.changeset(params)
    |> Changeset.put_assoc(:groups, groups)
    |> Repo.insert
  end

  defp generate_message_id() do
    #todo: pull in hostname
    id = UUID.generate() |> String.replace("-", ".")
    "#{id}@localhost"
  end

end
