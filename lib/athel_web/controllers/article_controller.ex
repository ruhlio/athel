defmodule AthelWeb.ArticleController do
  use AthelWeb, :controller
  use Timex

  alias Athel.Article

  def show(conn, %{"message_id" => id}) do
    articles = Repo.all(
      from a in Article,
      join: t in fragment(
        """
        WITH RECURSIVE thread AS (
          SELECT * FROM articles WHERE message_id = ?
          UNION ALL
          SELECT a.* FROM articles a
          JOIN thread t on a.parent_message_id = t.message_id)
        SELECT * FROM thread
        """, ^id), on: a.message_id == t.message_id)

    render(conn, "show.html", articles: articles)
  end

end
