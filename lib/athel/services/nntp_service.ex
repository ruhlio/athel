defmodule Athel.NntpService do
  require Logger

  import Ecto.Query
  alias Ecto.{Changeset, UUID}
  alias Athel.{Repo, Group, Article, Multipart}

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

  @spec get_groups_created_after(Timex.DateTime) :: list(Group.t)
  def get_groups_created_after(date) do
    Repo.all(from g in Group,
      where: g.inserted_at > ^date,
      order_by: g.inserted_at)
  end

  @spec get_article(String.t) :: Article.t | nil
  def get_article(message_id) do
    Repo.one(from a in Article,
      where: a.message_id == ^message_id and a.status == "active",
      left_join: at in assoc(a, :attachments),
      preload: [attachments: at],
      preload: [:groups])
  end

  @spec get_articles_created_after(String.t, Timex.DateTime) :: list(Article.t)
  def get_articles_created_after(group_name, date) do
    Repo.all(from a in Article,
      join: g in assoc(a, :groups),
      left_join: at in assoc(a, :attachments),
      preload: [attachments: at],
      preload: [:groups],
      where: a.date > ^date and g.name == ^group_name,
      order_by: a.inserted_at)
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
    |> join(:left, [a], at in assoc(a, :attachments))
    |> preload([_a, at], attachments: at)
    |> preload(:groups)
    |> offset(^lower_bound)
    |> order_by(:date)
    |> select([a, _at, i], {i.index, a})
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
    config = Application.fetch_env!(:athel, Athel.Nntp)
    hostname = config[:hostname]

    #TODO: user logged in user's name/email for FROM
    save_article(headers, body,
      %{message_id: generate_message_id(hostname),
        from: headers["FROM"],
        subject: headers["SUBJECT"],
        date: Timex.now(),
        content_type: headers["CONTENT-TYPE"],
        status: "active"})
  end

  @spec take_article(headers, list(String.t)) :: new_article_result
  def take_article(headers, body) do
    save_article(headers, body,
      %{message_id: headers["MESSAGE-ID"],
        date: headers["DATE"],
        from: headers["FROM"],
        subject: headers["SUBJECT"],
        content_type: headers["CONTENT-TYPE"],
        status: "active"})
  end

  defp save_article(headers, body, params) do
    with {:ok, {body, attachments}} <- read_body(headers, body) do
      changeset = Article.changeset(%Article{}, Map.put(params, :body, body))
      |> set_groups(headers)
      |> set_parent(headers)
      |> set_attachments(attachments)
      |> Changeset.put_assoc(:attachments, attachments)

      Repo.insert(changeset)
    end
  end

  defp set_groups(changeset, headers) do
    group_names = headers
    |> Map.get("NEWSGROUPS", "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    groups = Repo.all(from g in Group, where: g.name in ^group_names)

    cond do
      length(groups) == 0 || length(group_names) != length(groups) ->
        Changeset.add_error(changeset, :groups, "is invalid")
      Enum.any?(groups, &(&1.status == "n")) ->
        #TODO: move this to the base changeset? or the group changeset?
        Changeset.add_error(changeset, :groups, "doesn't allow posting")
      true ->
        Changeset.put_assoc(changeset, :groups, groups)
    end
  end

  defp set_parent(changeset, headers) do
    parent_message_id = headers["REFERENCES"]
    parent = unless is_nil(parent_message_id) do
      Repo.get(Article, parent_message_id)
    end

    if is_nil(parent) && !is_nil(parent_message_id) do
      Changeset.add_error(changeset, :parent, "is invalid")
    else
      Changeset.put_assoc(changeset, :parent, parent)
    end
  end

  defp set_attachments(changeset, attachments) do
    config = Application.fetch_env!(:athel, Athel.Nntp)
    max_attachment_count = config[:max_attachment_count]

    if length(attachments) > max_attachment_count do
      Changeset.add_error(changeset, :attachments,
        "limited to #{max_attachment_count}")
    else
      Changeset.put_assoc(changeset, :attachments, attachments)
    end
  end

  defp read_body(headers, body) do
    case Multipart.get_boundary(headers) do
      {:ok, nil} ->
        {:ok, {body, []}}
      {:ok, boundary} ->
        case Multipart.read_attachments(body, boundary) do
          {:ok, attachments} -> {:ok, split_attachments(attachments)}
          error -> error
        end
      error ->
        error
    end
  end

  defp split_attachments([]), do: {[], []}

  defp split_attachments(attachments) do
    [first | rest] = attachments
    if is_nil(first.filename) do
      body = split_body(first.content)
      {body, rest |> join_attachment_contents}
    else
      {[], attachments |> join_attachment_contents}
    end
  end

  defp split_body(body) when is_list(body), do: body

  defp split_body(body) do
    body |> String.split(~r/(\r\n)|\n|\r/)
  end

  defp join_attachment_contents(attachments) do
    attachments |> Enum.map(fn attachment ->
      %{attachment | content: attachment.content |> join_body}
    end)
  end

  defp join_body(body) when is_list(body), do: Enum.join(body, "\n")

  defp join_body(body), do: body

  @spec new_topic(list(Group.t), changeset_params) :: new_article_result
  def new_topic(groups, params) do
    config = Application.fetch_env!(:athel, Athel.Nntp)
    hostname = config[:hostname]

    params = Map.merge(params,
      %{message_id: generate_message_id(hostname),
        parent: nil,
        date: Timex.now()})

    %Article{}
    |> Article.changeset(params)
    |> Changeset.put_assoc(:groups, groups)
    |> Repo.insert
  end

  defp generate_message_id(hostname) do
    id = UUID.generate() |> String.replace("-", ".")
    "#{id}@#{hostname}"
  end

end
