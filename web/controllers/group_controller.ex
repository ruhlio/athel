defmodule Athel.GroupController do
  use Athel.Web, :controller

  alias Athel.{NntpService, Group, Article}

  def index(conn, _params) do
    groups = Repo.all(Group)
    render(conn, "index.html", groups: groups)
  end

  def show(conn, %{"name" => name}) do
    group = get_group(name)
    article_changeset = Article.changeset(%Article{})
    render(conn, "show.html", group: group, article_changeset: article_changeset)
  end

  def create_topic(conn, %{
        "name" => name,
        "article" => %{"from" => from, "subject" => subject, "body" => body}}) do
    group = get_group(name)
    article_changes = %{
      from: from,
      subject: subject,
      body: String.split(body, "\n"),
      content_type: "text/plain",
      status: "active"
    }

    #TODO: move out of NntpService
    case NntpService.new_topic([group], article_changes) do
      {:ok, article} ->
        conn
        |> put_flash(:success, "Article posted")
        |> redirect(to: article_path(conn, :show, name, article.message_id))
      {:error, changeset} ->
        conn
        |> put_flash(:error, "Please correct the errors and resubmit")
        |> render("show.html", group: group, article_changeset: changeset)
    end
  end

  defp get_group(name) do
    Repo.one! from g in Group,
      left_join: a in assoc(g, :articles),
      where: g.name == ^name,
      preload: [articles: a]
  end

end
