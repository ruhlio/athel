defmodule Athel.ArticleTest do
  use Athel.ModelCase

  alias Athel.Article
  alias Athel.Group

  @valid_attrs %{message_id: "123@banana", body: "some content", content_type: "some content", date: Timex.now, from: "some content", reference: "some content", subject: "some content"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Article.changeset(%Article{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Article.changeset(%Article{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "message id format" do
    changeset = Article.changeset(%Article{}, %{@valid_attrs | message_id: "balogna"})
    assert changeset.errors[:message_id] == {"has invalid format", []}
  end

  test "message id uniqueness" do
    changeset = Article.changeset(%Article{}, @valid_attrs)
    Repo.insert!(changeset)

    changeset = Article.changeset(%Article{}, @valid_attrs)
    {:error, changeset} = Repo.insert(changeset)
    assert changeset.errors[:message_id] == {"has already been taken", []}
  end

  test "get by index" do
    group = setup_models(5)

    {index, article} = Repo.one! Article.by_index(group, 2)
    assert {index, article.message_id} == {2, "02@test.com"}

    articles = Repo.all Article.by_index(group, 2, :infinity)
    assert message_ids(articles) == [
      {2, "02@test.com"},
      {3, "03@test.com"},
      {4, "04@test.com"}
    ]

    articles = Repo.all Article.by_index(group, 2, 4)
    assert message_ids(articles) == [
      {2, "02@test.com"},
      {3, "03@test.com"}
    ]

    articles = Repo.all Article.by_index(group, 7, 5)
    assert articles == []

    group = Repo.update! Group.changeset(group, %{low_watermark: 2})
    articles = Repo.all Article.by_index(group, 1, :infinity)
    assert message_ids(articles) == [
      {2, "02@test.com"},
      {3, "03@test.com"},
      {4, "04@test.com"}
    ]
  end

  defp message_ids(articles) do
    Enum.map(articles, fn {row, article} -> {row, article.message_id} end)
  end

end
