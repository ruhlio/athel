defmodule AthelWeb.GroupController do
  use AthelWeb, :controller

  @articles_per_page 15
  @page_link_count 5

  def index(conn, _params) do
    groups = Repo.all(Athel.Group)
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
    page_count = ceil(article_count / @articles_per_page) - 1
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
    group = Repo.one!(from g in Athel.Group,
      where: g.name == ^name)
    article_source = if "" != query do
      Athel.ArticleSearchIndex
    else
      Athel.Article
    end

    article_query = from a in article_source,
      join: a2g in ^(from "articles_to_groups"), on: a2g.message_id == a.message_id,
      where: is_nil(a.parent_message_id),
      where: a2g.group_name == ^name,
      order_by: [desc: a.date],
      limit: @articles_per_page,
      offset: ^(page * @articles_per_page),
      select: {a, over(count())}

    articles = if "" != query do
      article_query
      |> where([a], fragment("? @@ to_tsquery(?::regconfig, ?)", a.document, a.language, ^query))
      |> Repo.all
    else
      Repo.all(article_query)
    end

    group = %{group | articles: Enum.map(articles, fn {article, _} -> article end)}
    article_count =
      case articles do
        [] -> 0
        [{_, count} | _] -> count
      end
    {group, article_count}
  end

end
