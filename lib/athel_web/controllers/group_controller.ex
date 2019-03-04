defmodule AthelWeb.GroupController do
  use AthelWeb, :controller

  alias Athel.Group

  @articles_per_page 15
  @page_link_count 5

  def index(conn, _params) do
    groups = Repo.all(Group)
    render(conn, "index.html", groups: groups)
  end

  def show(conn, params = %{"name" => name}) do
    {page, _} = params |> Map.get("page", "0") |> Integer.parse
    query = Map.get(params, "query", "")
    {group, article_count} = load_group(name, page, query)
    page_params = calculate_page_params(page, article_count)

    render(conn, "show.html",
      page_params ++ [group: group, article_count: article_count])
  end

  defp calculate_page_params(page, article_count) do
    page_count = ceil(article_count / @articles_per_page)
    # are these div/rem results inlined?
    pages_per_direction = div(@page_link_count, 2)
    page_offset = rem(@page_link_count, 2)
    page_range = if (pages_per_direction + page) >= page_count do
      max(0, page_count - @page_link_count)..page_count
    else
      start_page = max(0, page - pages_per_direction)
      end_page = min(page_count, start_page + @page_link_count - page_offset)
      start_page..end_page
    end

    [page: page,
     per_page: @articles_per_page,
     page_count: page_count,
     pages: page_range]
  end

  defp load_group(name, page, query) do
    base_query = from g in Group,
      where: g.name == ^name
    group_query = if "" != query do
      base_query
      |> join(:left, [g], a in assoc(g, :article_search_indexes))
      |> where([_, a], fragment("? is null or ? @@ to_tsquery(?::regconfig, ?)", a.document, a.document, a.language, ^query))
    else
      base_query
      |> join(:left, [g], a in assoc(g, :articles))
    end
    |> limit(@articles_per_page)
    |> offset(^(page * @articles_per_page))
    |> order_by([_, a], desc: a.date)
    |> preload([_, a], articles: a)

    group = Repo.one!(group_query)
    article_count = base_query
    |> select(count())
    |> Repo.one!

    {group, article_count}
  end

end
