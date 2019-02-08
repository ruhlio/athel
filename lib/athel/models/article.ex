defmodule Athel.Article do
  use Ecto.Schema

  import Ecto.Changeset
  alias Athel.{Group, Attachment}

  @primary_key {:message_id, :string, autogenerate: false}
  schema "articles" do
    field :from, :string
    field :subject, :string
    field :date, :utc_datetime
    field :content_type, :string
    field :status, :string
    field :headers, :map
    field :body, :string

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

  # against spec: allows consecutive .
  @message_id_format Regex.compile!("^<?([a-zA-Z0-9.!#$%&'*+-/=?_`{|}~^]{2,128}@[a-zA-Z0-9.-]{2,63})>?$")
  @date_format "%a, %d %b %Y %H:%M:%S %z"
  def date_format, do: @date_format

  def changeset(article, params \\ %{}) do
    article
    |> cast(params, [:message_id, :from, :subject, :status, :headers])
    |> cast_assoc(:groups)
    |> cast_date(params)
    |> parse_message_id
    |> cast_content_type(params)
    |> cast_body(params)
    |> cast_assoc(:parent, required: false)
    |> validate_headers()
    |> validate_required([:subject, :date, :content_type])
    |> validate_inclusion(:status, ["active", "banned"])
    |> validate_length(:from, max: 255)
    |> validate_length(:subject, max: 255)
  end

  def get_headers(article) do
    headers = Map.merge(article.headers,
      %{"NEWSGROUPS" => format_article_groups(article.groups),
        "MESSAGE-ID" => format_message_id(article.message_id),
        "REFERENCES" => format_message_id(article.parent_message_id),
        "FROM" => article.from,
        "SUBJECT" => article.subject,
        "DATE" => format_date(article.date)})

    if Enum.empty?(article.attachments) do
      {headers |> Map.put("CONTENT-TYPE", article.content_type), nil}
    else
      boundary = Ecto.UUID.generate()
      headers = headers
      |> Map.put("MIME-VERSION", "1.0")
      |> Map.put("CONTENT-TYPE", "multipart/mixed; boundary=\"#{boundary}\"")
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
      cond do
        is_binary(date) ->
          with {:ok, parsed_date} <- Timex.parse(date, @date_format, Timex.Parse.DateTime.Tokenizers.Strftime), do: {:ok, parsed_date |> sanitize_date()}
        nil == date ->
          {:ok, nil}
        true ->
          {:ok, date |> Timex.to_datetime() |> sanitize_date()}
      end
    end)
  end

  defp sanitize_date(date) do
    date
    |> DateTime.truncate(:second)
    |> Timex.Timezone.convert("Etc/UTC")
  end

  defp validate_headers(changeset) do
    if get_field(changeset, :headers) == nil do
      add_error(changeset, :headers, "is required")
    else
      changeset
    end
  end

  defp cast_content_type(changeset, params) do
    content_type = params[:content_type]
    parse_value(changeset, :content_type, fn _ ->
      case content_type do
        nil -> {:ok, "text/plain"}
        %{value: type} -> {:ok, type}
        type -> {:ok, type}
      end
    end)
  end

  defp cast_body(changeset, params = %{:body => body}) when is_list(body) do
    joined_body = Enum.join(body, "\n")
    cast_body(changeset, %{params | body: joined_body})
  end
  defp cast_body(changeset, params) do
    body = params[:body]
    new_body =
      case params[:content_type] do
        %{params: %{"CHARSET" => charset}} ->
          case map_encoding(charset) do
            nil -> body
            encoding ->
              Codepagex.to_string!(body, encoding)
          end
        _ -> body
      end

    new_changes = Map.put(changeset.changes, :body, new_body)
    %{changeset | changes: new_changes}
  catch
    e -> Ecto.Changeset.add_error(changeset, :body, Exception.message(e))
  end

  defp map_encoding(encoding) do
    encoding = String.upcase(encoding)
    case Regex.run(~r/^ISO-8859-(\d+)$/, encoding) do
      [_, subtype] -> "ISO8859/8859-#{subtype}"
      nil ->
        case Regex.run(~r/^WINDOWS-12(\d{2})$/, encoding) do
          [_, digits] -> "VENDORS/MICSFT/WINDOWS/CP12#{digits}"
          nil -> nil
        end
    end
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
    "<#{message_id}>"
  end

  defp format_date(date) when is_nil(date) do
    nil
  end

  defp format_date(date) do
    Timex.format!(date, Athel.Article.date_format, :strftime)
  end

  defp format_article_groups([]), do: ""
  defp format_article_groups(groups) do
    Enum.reduce(groups, :first, fn
      group, :first -> [group.name]
      group, acc -> [acc, ?,, group.name]
    end) |> IO.iodata_to_binary
  end

end

defimpl Athel.Nntp.Formattable, for: Athel.Article do
  alias Athel.Nntp.Formattable

  def format(article) do
    {headers, boundary} = Athel.Article.get_headers(article)
    split_body = String.split(article.body, "\n")
    body = if is_nil(boundary) do
      Formattable.format(split_body)
    else
      attachments = article.attachments |> Enum.map(fn attachment ->
        ["\r\n--", boundary, Formattable.format(attachment)]
      end)
      #NOTE: article lines won't be escaped (nested list won't pattern match),
      # which is ok since attachment content is always base64'd
      Formattable.format(split_body ++ [attachments, "--#{boundary}--"])
    end
    [Formattable.format(headers), body]
  end

end

