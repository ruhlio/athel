defmodule Athel.Article do
  use Ecto.Schema

  import Ecto.Changeset
  alias Athel.{Group, Attachment}

  @primary_key {:message_id, :string, autogenerate: false}
  schema "articles" do
    field :from, :string
    field :subject, :string
    field :date, Timex.Ecto.DateTime
    field :content_type, :string
    field :body, {:array, :string}

    field :status, :string

    many_to_many :groups, Group,
      join_through: "articles_to_groups",
      join_keys: [message_id: :message_id, group_id: :id]
    belongs_to :parent, __MODULE__,
      foreign_key: :parent_message_id,
      references: :message_id,
      type: :string
    many_to_many :attachments, Attachment,
      join_through: "attachments_to_articles",
      join_keys: [message_id: :message_id, attachment_id: :id]

    timestamps()
  end

  @message_id_format ~r/^<?([a-zA-Z0-9$.]{2,128}@[a-zA-Z0-9.-]{2,63})>?$/
  @date_format "%a, %d %b %Y %H:%M:%S %z"
  def date_format, do: @date_format

  def changeset(article, params \\ %{}) do
    article
    |> cast(params, [:message_id, :from, :subject, :body, :status])
    |> cast_assoc(:groups)
    |> cast_date(params)
    |> parse_message_id
    |> cast_content_type(params)
    |> cast_assoc(:parent, required: false)
    |> validate_required([:subject, :date, :content_type, :body])
    |> validate_inclusion(:status, ["active", "banned"])
  end

  def get_headers(article) do
    headers = %{"Newsgroups" => format_article_groups(article.groups),
                "Message-ID" => format_message_id(article.message_id),
                "References" => format_message_id(article.parent_message_id),
                "From" => article.from,
                "Subject" => article.subject,
                "Date" => format_date(article.date)}
    if Enum.empty?(article.attachments) do
      {headers |> Map.put("Content-Type", article.content_type), nil}
    else
      boundary = Ecto.UUID.generate()
      headers = headers
      |> Map.put("MIME-Version", "1.0")
      |> Map.put("Content-Type", "multipart/mixed; boundary=\"#{boundary}\"")
      {headers, boundary}
    end
  end

  defp parse_message_id(changeset) do
    parse_value(changeset, :message_id, fn message_id ->
      case Regex.run(@message_id_format, message_id) do
        nil -> {:error, "has invalid format"}
        [_, id] -> {:ok, id}
      end
    end)
  end

  defp cast_date(changeset, params) do
    date = params[:date]
    parse_value(changeset, :date, fn _ ->
      if is_binary(date) do
        Timex.parse(date, @date_format, Timex.Parse.DateTime.Tokenizers.Strftime)
      else
        {:ok, date}
      end
    end)
  end

  defp cast_content_type(changeset, params) do
    content_type = params[:content_type]
    parse_value(changeset, :content_type, fn _ ->
      case content_type do
        nil -> {:ok, "text/plain"}
        #TODO: handle charset param
        {type, _} -> {:ok, type}
        type -> {:ok, type}
      end
    end)
  end

  defp parse_value(changeset = %{changes: changes, errors: errors}, key, parser) do
    value = Map.get(changeset.changes, key, "")
    case parser.(value) do
      {:error, message} ->
        error = {key, {message, []}}
        %{changeset | errors: [error | errors], valid?: false}
      {:ok, new_value} ->
        new_changes = Map.put(changes, key, new_value)
        %{changeset | changes: new_changes}
    end
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
    Timex.format!(date, Athel.Article.date_format, :strftime)
  end

  defp format_article_groups(groups) do
    Enum.reduce(groups, :first, fn
      group, :first -> [group.name]
      group, acc -> [acc, ?,, group.name]
    end)
  end

end

defimpl Athel.Nntp.Formattable, for: Athel.Article do
  alias Athel.Nntp.Formattable

  def format(article) do
    {headers, boundary} = Athel.Article.get_headers(article)
    body = if is_nil(boundary) do
      Formattable.format(article.body)
    else
      attachments = article.attachments |> Enum.map(fn attachment ->
        ["\r\n--", boundary, Formattable.format(attachment)]
      end)
      #NOTE: article lines won't be escaped (nested list won't pattern match),
      # which is ok since attachment content is always base64'd
      Formattable.format(article.body ++ [attachments, "--#{boundary}--"])
    end
    [Formattable.format(headers), body]
  end

end

