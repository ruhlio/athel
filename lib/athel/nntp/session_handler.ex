defmodule Athel.Nntp.SessionHandler do
  use GenServer

  require Logger
  import Ecto.Query

  require Athel.Nntp.Defs
  import Athel.Nntp.Defs
  alias Athel.{Repo, Group, Article}

  defmodule State do
    defstruct group_name: nil, article_index: nil
  end

  def start_link do
    GenServer.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    {:ok, %State{}}
  end

  # Command handling

  defmacrop respond(type, response) do
    quote do: {:reply, {unquote(type), unquote(response)}, var!(state)}
  end

  check_argument_count("CAPABILITIES", 0)
  def handle_call({"CAPABILITIES", _}, _sender, state) do
    capabilities = ["VERSION 2", "POST", "LIST ACTIVE NEWGROUPS", "STARTTLS"]
    respond(:continue, {101, "Listing capabilities", capabilities})
  end

  check_argument_count("QUIT", 0)
  def handle_call({"QUIT", _}, _sender, state) do
    respond(:quit, {205, "SEE YA"})
  end

  #TODO: LIST ACTIVE with wildmat
  check_argument_count("LIST", 2)
  def handle_call({"LIST", []}, sender, state) do
    handle_call({"LIST", ["ACTIVE"]}, sender, state)
  end

  @lint {Credo.Check.Refactor.PipeChainStart, false}
  def handle_call({"LIST", ["ACTIVE"]}, _sender, state) do
    groups = from(g in Group, order_by: :name)
    |> Repo.all
    |> Enum.map(&("#{&1.name} #{&1.high_watermark} #{&1.low_watermark} #{&1.status}"))
    respond(:continue, {215, "Listing groups", groups})
  end

  @lint {Credo.Check.Refactor.PipeChainStart, false}
  def handle_call({"LIST", ["NEWSGROUPS"]}, _sender, state) do
    groups = from(g in Group, order_by: :name)
    |> Repo.all
    |> Enum.map(&("#{&1.name} #{&1.description}"))
    respond(:continue, {215, "Listing group descriptions", groups})
  end

  def handle_call({"LIST", _}, _sender, state) do
    respond(:error, {501, "Invalid LIST arguments"})
  end

  check_argument_count("LISTGROUP", 2)
  def handle_call({"LISTGROUP", []}, sender, state) do
    case state.group_name do
      nil -> respond(:continue, {412, "Select a group first, ya dingus"})
      group_name -> handle_call({"LISTGROUP", [group_name, "1-"]}, sender, state)
    end
  end

  def handle_call({"LISTGROUP", [group_name]}, sender, state) do
    handle_call({"LISTGROUP", [group_name, "1-"]}, sender, state)
  end

  def handle_call({"LISTGROUP", [group_name, range]}, _sender, state) do
    case Repo.get_by(Group, name: group_name) do
      nil -> respond(:continue, {411, "No such group"})
      group ->
        case Regex.run(~r/(\d+)(-(\d+)?)?/, range) do
          [_, index] ->
            {index, _} = Integer.parse(index)
            group
            |> Article.by_index(index)
            |> listgroup_response(group, state)
          [_, lower_bound, _unbounded] ->
            {lower_bound, _} = Integer.parse(lower_bound)
            group
            |> Article.by_index(lower_bound, :infinity)
            |> listgroup_response(group, state)
          [_, lower_bound, _, upper_bound] ->
            {lower_bound, _} = Integer.parse(lower_bound)
            {upper_bound, _} = Integer.parse(upper_bound)
            group
            |> Article.by_index(lower_bound, upper_bound)
            |> listgroup_response(group, state)
          nil ->
            respond(:error, {501, "Syntax error in range argument"})
        end
    end
  end

  defp listgroup_response(query, group, state) do
    indexes = query |> Repo.all |> Enum.map(fn {index, _article} -> index end)
    {
      :reply,
      {:continue, {211, format_group_status(group), indexes}},
      %{state | group_name: group.name}
    }
  end

  check_argument_count("GROUP", 1)
  def handle_call({"GROUP", []}, _sender, state) do
    respond(:error, {501, "Syntax error: group name must be provided"})
  end

  def handle_call({"GROUP", [group_name]}, _sender, state) do
    case Repo.get_by(Group, name: group_name) do
      nil ->
        respond(:continue, {411, "No such group"})
      group ->
        {
          :reply,
          {:continue, {211, format_group_status(group)}},
          %{state | group_name: group.name}
        }
    end
  end

  defp format_group_status(group) do
    "#{group.high_watermark - group.low_watermark} #{group.low_watermark} #{group.high_watermark} #{group.name}"
  end

  check_argument_count("ARTICLE", 1)
  def handle_call({"ARTICLE", []}, sender, state) do
    case state.article_index do
      nil -> respond(:continue, {420, "BLAISE IT"})
      article_index -> handle_call({"ARTICLE", [article_index]}, sender, state)
    end
  end

  def handle_call({"ARTICLE", [id]}, _sender, state) do
    message_id =
      case Regex.run(~r/^<(.*)>$/, to_string(id)) do
        [_, id] -> id
        _ -> nil
      end

    cond do
      !is_nil(message_id) ->
        case Repo.get(Article, message_id) do
          nil ->
            respond(:continue, {430, "No such article"})
          article ->
            respond(:continue, {220, "0 #{id}", article |> Repo.preload(:groups)})
        end
      to_string(id) =~ ~r/^\d+$/ ->
        case state.group_name do
          nil -> respond(:continue, {412, "You ain't touchin none my articles till you touch one of my groups"})
          group_name ->
            {index, _} = if is_number(id), do: {id, ()}, else: Integer.parse(id)
            state = %{state | article_index: index}
            group = Repo.get_by(Group, name: group_name)
            article = group
            |> Article.by_index(index)
            |> Repo.one

            cond do
              is_nil(article) && is_number(id) ->
                respond(:continue, {420, "BLAISE IT"})
              is_nil(article) ->
                respond(:continue, {423, "Bad index bro"})
              true ->
                {_, article} = article
                respond(:continue, {220, "#{index} <#{article.message_id}>",
                                    article |> Repo.preload(:groups)})
            end
        end
      true ->
        respond(:error, {501, "Invalid message id/index"})
    end
  end

  check_argument_count("POST", 0)
  def handle_call({"POST", []}, _sender, state) do
    respond(:recv_article, {340, "FIRE AWAY"})
  end

  def handle_call({:article, headers, body}, _sender, state) do
    case Repo.insert Article.post_changeset(%Article{}, headers, body) do
      {:ok, _} -> {:reply, {240, "Thank you for your input"}, state}
      #TODO: cleaner error message
      {:error, changeset} -> {:reply, {441, inspect(changeset.errors)}, state}
    end
  end

  def handle_call({"MODE", ["READER"]}, _sender, state) do
    respond(:continue, {200, "Whatever dude"})
  end

  @check_argument_count(0)
  def handle_call({"STARTTLS", []}, _sender, state) do
    #TODO: 502 if authed
    {:reply,
     {:start_tls,
      {382, "Slap that rubber on"},
      {502, "Already protected"}},
     state}
  end

  def handle_call({other, args}, _sender, state) do
    respond(:continue, {501, "Unknown command #{other} #{args}"})
  end

end
