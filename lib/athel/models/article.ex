defmodule Athel.Article do
  use Athel.Web, :model

  alias Ecto.UUID
  alias Ecto.Changeset

  alias Athel.Group

  @type changeset_params :: %{optional(binary) => term} | %{optional(atom) => term}

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

  #TODO: __MODULE__ is incorrect
  @spec topic_changeset(__MODULE__, list(Group.t), changeset_params) :: Changeset.t
  def topic_changeset(article, groups, params) do
    params = Map.merge(params,
      %{
          message_id: generate_message_id(),
          parent: nil,
          date: Timex.now()
      })

    article
    |> changeset(params)
    |> Changeset.put_assoc(:groups, groups)
  end

  @spec post_changeset(struct, %{optional(String.t) => String.t}, list(String.t)) :: Changeset.t
  def post_changeset(article, headers, body) do
    params = %{
      message_id: generate_message_id(),
      from: headers["From"],
      subject: headers["Subject"],
      date: Timex.now(),
      content_type: headers["Content-Type"],
      body: Enum.join(body, "\n")
    }

    group_names = headers
    |> Map.get("Newsgroups", "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    #TODO: move all queries outside of model
    groups = Athel.Repo.all from(g in Group, where: g.name in ^group_names)
    parent_message_id = headers["References"]
    parent = unless is_nil(parent_message_id), do: Athel.Repo.get(__MODULE__, parent_message_id)

    changeset = changeset(article, params)

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

    changeset
  end

  defp generate_message_id() do
    #todo: pull in hostname
    id = UUID.generate() |> String.replace("-", ".")
    "#{id}@localhost"
  end

  @spec by_index(Group.t, integer) :: Query.t
  def by_index(group, index) do
    group |> base_by_index(index) |> limit(1)
  end

  @spec by_index(Group.t, integer, :infinity) :: Query.t
  def by_index(group, lower_bound, :infinity) do
    group |> base_by_index(lower_bound)
  end

  @spec by_index(Group.t, integer, integer) :: Query.t
  def by_index(group, lower_bound, upper_bound) do
    count = max(upper_bound - lower_bound, 0)
    group |> base_by_index(lower_bound) |> limit(^count)
  end

  defp base_by_index(group, lower_bound) do
    lower_bound = max(group.low_watermark, lower_bound)
    from a in __MODULE__,
      join: g in assoc(a, :groups),
      where: g.id == ^group.id,
      offset: ^lower_bound,
      order_by: :date,
      # make `row_number()` zero-indexed to match up with `offset`
      select: {fragment("(row_number() OVER (ORDER BY date) - 1)"), a}
  end

end
