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
    {group, article_count} = load_group(name, page)
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

    render(conn, "show.html",
      group: group,
      article_count: article_count,
      page: page,
      per_page: @articles_per_page,
      page_count: page_count,
      pages: page_range)
  end

  # def create_topic(conn, %{
  #       "name" => name,
  #       "article" => %{"from" => from, "subject" => subject, "body" => body}}) do
  #   group = Repo.one!(Group, name: name)
  #   article_changes = %{
  #     from: from,
  #     subject: subject,
  #     body: String.split(body, "\n"),
  #     content_type: "text/plain",
  #     status: "active"
  #   }

  #   #TODO: move out of NntpService
  #   case NntpService.new_topic([group], article_changes) do
  #     {:ok, article} ->
  #       conn
  #       |> put_flash(:success, "Article posted")
  #       |> redirect(to: article_path(conn, :show, name, article.message_id))
  #     {:error, changeset} ->
  #       conn
  #       |> put_flash(:error, "Please correct the errors and resubmit")
  #       |> render("show.html", group: group, article_changeset: changeset)
  #   end
  # end

  defp load_group(name, page) do
    group_query = from g in Group,
      left_join: a in assoc(g, :articles),
      where: g.name == ^name

    group = group_query
    |> limit(@articles_per_page)
    |> offset(^(page * @articles_per_page))
    |> order_by([_, a], desc: a.date)
    |> preload([_, a], articles: a)
    |> Repo.one!
    article_count = group_query
    |> select(count())
    |> Repo.one!

    {group, article_count}
  end

end
