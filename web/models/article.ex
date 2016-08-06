defmodule Athel.Article do
  use Athel.Web, :model

  alias Ecto.UUID
  alias Ecto.Changeset

  @type changeset_params :: %{optional(binary) => term} | %{optional(atom) => term}

  @primary_key {:message_id, :string, autogenerate: false}
  schema "articles" do
    field :from, :string
    field :subject, :string
    field :date, Timex.Ecto.DateTime
    field :reference, :string
    field :content_type, :string
    field :body, :string

    many_to_many :groups, Athel.Group,
      join_through: "articles_to_groups",
      join_keys: [message_id: :message_id, group_id: :id],
      on_delete: :delete_all

    timestamps()
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:message_id, :from, :subject, :date, :reference, :content_type, :body])
    |> cast_assoc(:groups)
    |> validate_format(:message_id, ~r/^[a-zA-Z0-9$.]{2,128}@[a-zA-Z0-9.-]{2,63}$/)
    |> unique_constraint(:message_id)
    |> validate_required([:subject, :date, :content_type, :body])
  end

  @spec topic_changeset(__MODULE__, list(Athel.Group.t), changeset_params) :: Changeset.t
  def topic_changeset(struct, groups, params \\ %{}) do
    #todo: pull in hostname
    id = UUID.generate() |> String.replace("-", ".")
    params = Map.merge(params,
      %{
          "message_id" => "#{id}@localhost",
          "reference" => nil,
          "date" => Timex.now()
      })

    struct
    |> changeset(params)
    |> Changeset.put_assoc(:groups, groups)
  end

  @spec by_index(Athel.Group.t, integer) :: Query.t
  def by_index(group, index) do
    group |> base_by_index(index) |> limit(1)
  end

  @spec by_index(Athel.Group.t, integer, :infinity) :: Query.t
  def by_index(group, lower_bound, :infinity) do
    group |> base_by_index(lower_bound)
  end

  @spec by_index(Athel.Group.t, integer, integer) :: Query.t
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
