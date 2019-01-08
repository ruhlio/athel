defmodule Athel.Nntp.SessionHandler do
  use GenServer

  require Logger
  require Athel.Nntp.Defs
  import Athel.Nntp.Defs
  alias Timex.Parse.DateTime.Tokenizers.Strftime
  alias Athel.{Repo, AuthService, NntpService, Group, Article, User}

  @date_format "%Y%m%d%H%M%S"

  def start_link do
    GenServer.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    {:ok, %{group_name: nil,
            article_index: nil,
            authentication: nil}}
  end

  command "CAPABILITIES", :capabilities, max_args: 0
  def capabilities([], state) do
    capabilities = ["VERSION 2", "READER", "POST", "LIST ACTIVE NEWGROUPS", "STARTTLS", "IHAVE", "STREAMING"]
    capabilities = if is_authenticated(state) do
      capabilities
    else
      capabilities ++ ["AUTHINFO USER"]
    end

    {:continue, {101, "Listing capabilities", capabilities}}
  end

  command "QUIT", :quit, max_args: 0
  def quit([], _) do
    {:quit, {205, "SEE YA"}}
  end

  command "MODE", :mode, max_args: 1
  def mode(["READER"], _) do
    {:continue, {200, "Whatever dude"}}
  end

  def mode(["STREAM"], _) do
    {:continue, {203, "Whatever tickles your fancy"}}
  end

  #TODO: LIST ACTIVE with wildmat
  command "LIST", :list_groups, max_args: 2
  def list_groups([], state) do
    list_groups(["ACTIVE"], state)
  end

  def list_groups(["ACTIVE"], _) do
    groups = NntpService.get_groups()
    |> Enum.map(&format_group/1)
    {:continue, {215, "Listing groups", groups}}
  end

  def list_groups(["NEWSGROUPS"], _) do
    groups = NntpService.get_groups()
    |> Enum.map(&("#{&1.name} #{&1.description}"))
    {:continue, {215, "Listing group descriptions", groups}}
  end

  command "GROUP", :select_group, max_args: 1
  def select_group([group_name], _) do
    case Repo.get_by(Group, name: group_name) do
      nil ->
        {:continue, {411, "No such group"}}
      group ->
        {:continue, {211, format_group_status(group)}, %{group_name: group.name}}
    end
  end

  defp format_group_status(group) do
    "#{group.high_watermark - group.low_watermark} #{group.low_watermark} #{group.high_watermark} #{group.name}"
  end

  command "LISTGROUP", :list_articles, max_args: 2
  def list_articles([], state) do
    case state.group_name do
      nil -> no_group_selected()
      group_name -> list_articles([group_name, "1-"], state)
    end
  end

  def list_articles([group_name], state) do
    list_articles([group_name, "1-"], state)
  end

  def list_articles([group_name, range], _) do
    get_articles(range, group_name, &list_articles_response/2)
  end

  defp list_articles_response(articles, group) do
    indexes = articles |> Enum.map(fn {index, _article} -> index end)
    {:continue, {211, format_group_status(group), indexes}, %{group_name: group.name}}
  end

  command "XOVER", :xover, max_args: 2
  def xover([], state) do
    case state.article_index do
      nil -> no_article_selected()
      index -> xover(["#{index}"], state)
    end
  end

  def xover([range], state) do
    case state.group_name do
      nil -> no_group_selected()
      group_name -> get_articles(range, group_name, &xover_response/2)
    end
  end

  defp xover_response(articles, group) when is_list(articles) do
    metadata = Enum.map(articles, fn {index, article} ->
      date = Timex.format!(article.date, @date_format, :strftime)
      size = String.length(article.body)
      line_count = length(Regex.scan(~r/\n/, article.body)) + 1
      "#{index}\t#{article.subject}\t#{article.from}\t#{date}\t#{article.message_id}\t#{article.parent_message_id}\t#{size}\t#{line_count}"
    end)
    {:continue, {224, "XOVER OVER", metadata}}
  end

  defp xover_response(article, group) do
    xover_response([article], group)
  end

  defp get_articles(range, group_name, responder) do
    case NntpService.get_group(group_name) do
      nil -> {:continue, {411, "No such group"}}
      group ->
        case Regex.run(~r/(\d+)(-(\d+)?)?/, range) do
          [_, index] ->
            {index, _} = Integer.parse(index)
            group
            |> NntpService.get_article_by_index(index)
            |> responder.(group)
          [_, lower_bound, _unbounded] ->
            {lower_bound, _} = Integer.parse(lower_bound)
            group
            |> NntpService.get_article_by_index(lower_bound, :infinity)
            |> responder.(group)
          [_, lower_bound, _, upper_bound] ->
            {lower_bound, _} = Integer.parse(lower_bound)
            {upper_bound, _} = Integer.parse(upper_bound)
            group
            |> NntpService.get_article_by_index(lower_bound, upper_bound)
            |> responder.(group)
          nil ->
            {:error, {501, "Syntax error in range argument"}}
        end
    end
  end

  command "LAST", :select_previous_article, max_args: 0
  def select_previous_article([], state) do
    cond do
      is_nil(state.group_name) ->
        no_group_selected()
      is_nil(state.article_index) ->
        no_article_selected()
      true ->
        no_previous_article = {:continue, {422, "No previous article"}}
        group = NntpService.get_group(state.group_name)
        if group.low_watermark == state.article_index do
          no_previous_article
        else
          case NntpService.get_article_by_index(group, state.article_index - 1) do
            nil -> no_previous_article
            {index, article} -> {:continue, {223, "#{index} <#{article.message_id}>"}}
          end
        end
    end
  end

  command "NEXT", :select_next_article, max_args: 0
  def select_next_article([], state) do
    cond do
      is_nil(state.group_name) ->
        no_group_selected()
      is_nil(state.article_index) ->
        no_article_selected()
      true ->
        no_next_article = {:continue, {421, "No next article"}}
        group = NntpService.get_group(state.group_name)
        if group.high_watermark == state.article_index do
          no_next_article
        else
          case NntpService.get_article_by_index(group, state.article_index + 1) do
            nil -> no_next_article
            {index, article} -> {:continue, {223, "#{index} <#{article.message_id}>"}}
          end
        end
    end
  end

  command "ARTICLE", :get_article, max_args: 1
  def get_article(args, state), do: retrieve(&(&1), args, state)

  command "HEAD", :get_article_headers, max_args: 1
  def get_article_headers(args, state) do
    retrieve(fn article ->
      {headers, _} = Article.get_headers(article)
      headers
    end, args, state)
  end

  command "BODY", :get_article_body, max_args: 1
  def get_article_body(args, state), do: retrieve(&(&1.body |> String.split("\n")), args, state)

  command "STAT", :get_article_stat, max_args: 1
  def get_article_stat(args, state), do: retrieve(nil, args, state)

  defp retrieve(extractor, [], state) do
    case state.article_index do
      nil -> no_article_selected()
      article_index -> retrieve(extractor, [article_index], state)
    end
  end

  defp retrieve(extractor, [id], state) do
    message_id = extract_message_id(id)

    cond do
      !is_nil(message_id) ->
        case NntpService.get_article(message_id) do
          nil ->
            {:continue, {430, "No such article"}}
          article ->
            {:continue, retrieve_response(extractor, 0, article)}
        end
      to_string(id) =~ ~r/^\d+$/ ->
        case state.group_name do
          nil ->
            no_group_selected()
          group_name ->
            {index, _} = if is_number(id), do: {id, nil}, else: Integer.parse(id)
            group = Repo.get_by(Group, name: group_name)
            article = NntpService.get_article_by_index(group, index)

            cond do
              is_nil(article) && is_number(id) ->
                no_article_selected()
              is_nil(article) ->
                {:continue, {423, "Bad index bro"}}
              true ->
                {_, article} = article
                {:continue,
                 retrieve_response(extractor, index, article),
                 %{article_index: index}}
            end
        end
      true ->
        {:error, {501, "Invalid message id/index"}}
    end
  end

  # STAT has an edge case response
  defp retrieve_response(nil, index, article) do
    {223, "#{index} <#{article.message_id}>"}
  end

  defp retrieve_response(extractor, index, article) do
    extracted = article |> extractor.()
    {220, "#{index} <#{article.message_id}>", extracted}
  end

  command "POST", :post_article,
    max_args: 0,
    auth: [required: true, response: {440, "Authentication required"}]
  def post_article([], _) do
    {{:recv_article, :post}, {340, "FIRE AWAY"}}
  end

  def handle_call({:post_article, headers, body}, _sender, state) do
    case NntpService.post_article(headers, body) do
      {:ok, article} ->
        Logger.debug fn -> "Article <#{article.message_id}> posted from #{get_username(state)}" end
        {:reply, {240, "Your input is appreciated"}, state}
      #TODO: cleaner error message
      {:error, changeset} ->
        Logger.debug fn -> "Invalid article <#{changeset.changes[:message_id]}> posted from #{get_username(state)} (#{inspect(changeset.errors)})" end
        {:reply, {441, inspect(changeset.errors)}, state}
    end
  end

  command "IHAVE", :take_article,
    max_args: 1,
    auth: [required: true]
  def take_article([id], _) do
    case extract_message_id(id) do
      nil -> invalid_message_id()
      message_id ->
        case NntpService.get_article(message_id) do
          nil -> {{:recv_article, :take}, {335, "SEND YOUR ARTICLE OVER, OVER"}}
          _article -> {:continue, {435, "Pfff, I already have that one loser"}}
        end
    end
  end

  def handle_call({:take_article, headers, body}, _sender, state) do
    case NntpService.take_article(headers, body) do
      {:ok, article} ->
        Logger.debug fn -> "Article <#{article.message_id}> taken from #{get_username(state)}" end
        {:reply, {235, "Article transferred"}, state}
      #TODO: cleaner error message
      {:error, changeset} ->
        Logger.warn("Invalid article <#{changeset.changes[:message_id]}> rejected from #{get_username(state)} (#{inspect(changeset.errors)})")
        {:reply, {436, inspect(changeset.errors)}, state}
    end
  end

  command "CHECK", :check_article, max_args: 1, auth: [require: true]
  def check_article([id], _) do
    case extract_message_id(id) do
      nil -> invalid_message_id()
      message_id ->
        case NntpService.get_article(message_id) do
          nil ->
            Logger.debug fn -> "Successful CHECK for <#{message_id}>" end
            {:continue, {238, "<#{message_id}>"}}
          _article ->
            Logger.debug fn -> "Denied CHECK for <#{message_id}>" end
            {:continue, {438, "<#{message_id}>"}}
        end
    end
  end

  command "TAKETHIS", :take_streamed_article, max_args: 1, auth: [require: true]
  def take_streamed_article([id], _) do
    case extract_message_id(id) do
      nil -> invalid_message_id()
      message_id ->
        case NntpService.get_article(message_id) do
          nil ->
            Logger.debug fn -> "Taking article <#{message_id}>" end
            {{:recv_article, :take_streamed}, nil}
          _article ->
            Logger.debug fn -> "Denying taking of article <#{message_id}>" end
            {:kill_article, {439, "<#{message_id}>"}}
        end
    end
  end

  def handle_call({:take_streamed_article, headers, body}, _sender, state) do
    case NntpService.take_article(headers, body) do
      {:ok, article} ->
        Logger.debug fn -> "Streamed article <#{article.message_id}> taken from #{get_username(state)}" end
        {:reply, {239, "<#{article.message_id}>"}, state}
      {:error, changeset} ->
        Logger.warn("Invalid streamed article <#{changeset.changes[:message_id]}> rejected from #{get_username(state)} (#{inspect(changeset.errors)})")
        {:reply, {439, "<#{changeset.changes[:message_id]}>"}, state}
    end
  end

  command "DATE", :get_date, max_args: 0
  def get_date([], _) do
    date = Timex.format!(Timex.now(), @date_format, :strftime)
    {:continue, {111, date}}
  end

  command "NEWGROUPS", :get_new_groups, max_args: 2
  def get_new_groups([date, time], _) do
    parse_datetime(date, time, fn date ->
      groups = date
      |> NntpService.get_groups_created_after()
      |> Enum.map(&format_group/1)
      {:continue, {231, "HERE WE GO", groups}}
    end)
  end

  command "NEWNEWS", :get_new_articles, max_args: 3
  #TODO: implement wildmat
  def get_new_articles([group_name, date, time], _) do
    parse_datetime(date, time, fn date ->
      message_ids = group_name
      |> NntpService.get_articles_created_after(date)
      |> Enum.map(&("<#{&1.message_id}>"))
      {:continue, {230, "HOO-WEE", message_ids}}
    end)
  end

  #deviation from the spec: doesn't support 2 digit years or seconds
  def parse_datetime(date, time, valid) do
    case Timex.parse("#{date}#{time}", "%Y%m%d%H%M", Strftime) do
      {:ok, date} -> valid.(date)
      {:error, _} -> {:error, {501, "Invalid date/time, supported format is 'yyyymmdd hhmm'"}}
    end
  end

  command "STARTTLS", :start_tls, max_args: 0
  def start_tls([], state) do
    if is_authenticated(state) do
      {:continue, {502, "But we're already on a first name basis..."}}
    else
      {:start_tls, {{382, "Slap that rubber on"}, {502, "Already protected"}}}
    end
  end

  command "AUTHINFO", :login, max_args: 2
  def login(["USER", username], state) do
    if is_authenticated(state) do
      {:continue, {502, "Already authenticated"}}
    else
      {:continue, {381, "PROCEED"}, %{authentication: username}}
    end
  end

  def login(["PASS", password], state) do
    case state.authentication do
      nil ->
        {:continue, {482, "Call `AUTHINFO USER` first"}}
      %User{} ->
        {:continue, {502, "Already authenticated"}}
      username ->
        case AuthService.login(username, password) do
          {:ok, user} ->
            Logger.info("User #{username} logged in")
            {:continue, {281, "Authentication successful"}, %{authentication: user}}
          :invalid_credentials ->
            {:continue, {481, "No bueno"}, %{authentication: nil}}
        end
    end
  end

  def handle_call({other_command, _}, _sender, state) do
    message = "Unknown command #{other_command}"
    Logger.debug message
    {:reply, {:continue, {501, message}}, state}
  end

  defp format_group(group) do
    "#{group.name} #{group.high_watermark} #{group.low_watermark} #{group.status}"
  end

  @message_id_format ~r/^<([a-zA-Z0-9$.]{2,128}@[a-zA-Z0-9.-]{2,63})>$/
  defp extract_message_id(id) do
    case Regex.run(@message_id_format, to_string(id)) do
      [_, id] -> id
      _ -> nil
    end
  end

  defp invalid_message_id do
    {:error, {501, "Invalid message-ID"}}
  end

  defp no_group_selected do
    {:continue, {412, "Select a group first, ya dingus"}}
  end

  defp no_article_selected do
    {:continue, {420, "BLAISE IT"}}
  end

end
