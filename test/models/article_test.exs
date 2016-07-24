defmodule Athel.ArticleTest do
  use Athel.ModelCase

  alias Athel.Article

  @valid_attrs %{body: "some content", content_type: "some content", date: Timex.now, from: "some content", reference: "some content", subject: "some content"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Article.changeset(%Article{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Article.changeset(%Article{}, @invalid_attrs)
    refute changeset.valid?
  end
end
