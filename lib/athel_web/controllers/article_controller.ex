defmodule AthelWeb.ArticleController do
  use AthelWeb, :controller
  use Timex

  alias Athel.Article

  def show(conn, %{"message_id" => id}) do
    article = Repo.get!(Article, id)
    render(conn, "show.html", article: article)
  end

end
