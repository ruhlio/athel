defmodule Athel.Nntp.SessionHandler do
  use GenServer

  require Logger
  require Athel.Nntp.Defs
  import Athel.Nntp.Defs
  alias Athel.{Repo, AuthService, MessageBoardService, Group, Article, User}

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
    capabilities = ["VERSION 2", "POST", "LIST ACTIVE NEWGROUPS", "STARTTLS", "IHAVE"]
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

  #TODO: LIST ACTIVE with wildmat
  command "LIST", :list_groups, max_args: 2
  def list_groups([], state) do
    list_groups(["ACTIVE"], state)
  end

  def list_groups(["ACTIVE"], _) do
    groups = MessageBoardService.get_groups()
    |> Enum.map(&("#{&1.name} #{&1.high_watermark} #{&1.low_watermark} #{&1.status}"))
    {:continue, {215, "Listing groups", groups}}
  end

  def list_groups(["NEWSGROUPS"], _) do
    groups = MessageBoardService.get_groups()
    |> Enum.map(&("#{&1.name} #{&1.description}"))
    {:continue, {215, "Listing group descriptions", groups}}
  end

  command "LISTGROUP", :list_articles, max_args: 2
  def list_articles([], state) do
    case state.group_name do
      nil -> {:continue, {412, "Select a group first, ya dingus"}}
      group_name -> list_articles([group_name, "1-"], state)
    end
  end

  def list_articles([group_name], state) do
    list_articles([group_name, "1-"], state)
  end

  def list_articles([group_name, range], _) do
    case Repo.get_by(Group, name: group_name) do
      nil -> {:continue, {411, "No such group"}}
      group ->
        case Regex.run(~r/(\d+)(-(\d+)?)?/, range) do
          [_, index] ->
            {index, _} = Integer.parse(index)
            group
            |> MessageBoardService.get_article_by_index(index)
            |> list_articles_response(group)
          [_, lower_bound, _unbounded] ->
            {lower_bound, _} = Integer.parse(lower_bound)
            group
            |> MessageBoardService.get_article_by_index(lower_bound, :infinity)
            |> list_articles_response(group)
          [_, lower_bound, _, upper_bound] ->
            {lower_bound, _} = Integer.parse(lower_bound)
            {upper_bound, _} = Integer.parse(upper_bound)
            group
            |> MessageBoardService.get_article_by_index(lower_bound, upper_bound)
            |> list_articles_response(group)
          nil ->
            {:error, {501, "Syntax error in range argument"}}
        end
    end
  end

  defp list_articles_response(articles, group) do
    indexes = articles |> Enum.map(fn {index, _article} -> index end)
    {:continue, {211, format_group_status(group), indexes}, %{group_name: group.name}}
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

  command "ARTICLE", :get_article, max_args: 1
  def get_article([], state) do
    case state.article_index do
      nil -> {:continue, {420, "BLAISE IT"}}
      article_index -> get_article([article_index], state)
    end
  end

  def get_article([id], state) do
    message_id = extract_message_id(id)

    cond do
      !is_nil(message_id) ->
        case Repo.get(Article, message_id) do
          nil ->
            {:continue, {430, "No such article"}}
          article ->
            {:continue, {220, "0 #{id}", article |> Repo.preload(:groups)}}
        end
      to_string(id) =~ ~r/^\d+$/ ->
        case state.group_name do
          nil -> {:continue, {412, "You ain't touchin none my articles till you touch one of my groups"}}
          group_name ->
            {index, _} = if is_number(id), do: {id, ()}, else: Integer.parse(id)
            group = Repo.get_by(Group, name: group_name)
            article = MessageBoardService.get_article_by_index(group, index)

            cond do
              is_nil(article) && is_number(id) ->
                {:continue, {420, "BLAISE IT"}}
              is_nil(article) ->
                {:continue, {423, "Bad index bro"}}
              true ->
                {_, article} = article
                {:continue,
                 {220, "#{index} <#{article.message_id}>",
                  article |> Repo.preload(:groups)},
                 %{article_index: index}}
            end
        end
      true ->
        {:error, {501, "Invalid message id/index"}}
    end
  end

  command "POST", :post_article,
    max_args: 0,
    auth: [required: true, response: {440, "Authentication required"}]
  def post_article([], _) do
    {{:recv_article, :post}, {340, "FIRE AWAY"}}
  end

  def handle_call({:post_article, headers, body}, _sender, state) do
    case MessageBoardService.post_article(headers, body) do
      {:ok, _} -> {:reply, {240, "Your input is appreciated"}, state}
      #TODO: cleaner error message
      {:error, changeset} -> {:reply, {441, inspect(changeset.errors)}, state}
    end
  end

  command "IHAVE", :take_article,
    max_args: 1,
    auth: [required: true]
  def take_article([id], _) do
    case extract_message_id(id) do
      nil -> {:error, {501, "Invalid message-id"}}
      message_id ->
        case MessageBoardService.get_article(message_id) do
          nil -> {{:recv_article, :take}, {335, "SEND YOUR ARTICLE OVER, OVER"}}
          _article -> {:continue, {435, "Pfff, I already have that one loser"}}
        end
    end
  end

  def handle_call({:take_article, headers, body}, _sender, state) do
    case MessageBoardService.post_article(headers, body) do
      {:ok, _} -> {:reply, {235, "Article transferred"}, state}
      #TODO: cleaner error message
      {:error, changeset} -> {:reply, {436, inspect(changeset.errors)}, state}
    end
  end

  command "MODE", :mode, max_args: 1
  def mode(["READER"], _) do
    {:continue, {200, "Whatever dude"}}
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
            {:continue, {281, "Authentication successful"}, %{authentication: user}}
          :invalid_credentials ->
            {:continue, {481, "No bueno"}, %{authentication: nil}}
        end
    end
  end

  def handle_call({other_command, _}, _sender, state) do
    {:reply, {:continue, {501, "Unknown command #{other_command}"}}, state}
  end

  @message_id_format ~r/^<([a-zA-Z0-9$.]{2,128}@[a-zA-Z0-9.-]{2,63})>$/
  def extract_message_id(id) do
    case Regex.run(@message_id_format, to_string(id)) do
      [_, id] -> id
      _ -> nil
    end
  end

end
