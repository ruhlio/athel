defmodule AthelWeb.ArticleView do
  use AthelWeb, :view

  def title(_, assigns) do
    List.first(assigns.articles).subject
  end
end
