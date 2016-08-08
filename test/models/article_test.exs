defmodule Athel.ArticleTest do
  use Athel.ModelCase

  alias Athel.{Article, Group}

  @valid_attrs %{message_id: "123@banana", body: "some content", content_type: "some content", date: Timex.now, from: "some content", parent: nil, subject: "some content"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    group = setup_models()
    changeset = Article.changeset(%Article{}, @valid_attrs)
    |> put_assoc(:groups, [group])
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Article.changeset(%Article{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "message id format" do
    changeset = Article.changeset(%Article{}, %{@valid_attrs | message_id: "balogna"})
    assert error(changeset, :message_id) == "has invalid format"
  end

  test "message id uniqueness" do
    group = setup_models()

    changeset = Article.changeset(%Article{}, @valid_attrs)
    |> put_assoc(:groups, [group])
    Repo.insert!(changeset)

    changeset = Article.changeset(%Article{}, @valid_attrs)
    assert_raise Ecto.ConstraintError, fn -> Repo.insert(changeset) end
  end

  test "parent reference" do
    changeset = Article.changeset(%Article{}, @valid_attrs)
    Repo.insert! changeset

    parent = Repo.one!(from a in Article, limit: 1)
    changeset = Article.changeset(%Article{}, %{@valid_attrs | message_id: "fuggg@fin"})
    |> put_assoc(:parent, parent)
    Repo.insert! changeset
  end

  test "NNTP post" do
    group = setup_models()

    changeset = Article.post_changeset(%Article{}, %{"Newsgroups" => "heyo"}, [])
    assert error(changeset, :groups) == "is invalid"

    changeset = Article.post_changeset(%Article{}, %{}, [])
    assert error(changeset, :groups) == "is invalid"

    changeset = Article.post_changeset(%Article{}, %{"References" => "nothing"}, [])
    assert error(changeset, :parent) == "is invalid"

    headers = %{
      "From" => "Triple One",
      "Subject" => "Colors",
      "Content-Type" => "text/plain",
      "Newsgroups" => "fun.times"
    }
    body = ["All I see are these colors", "we walk with distant lovers", "but really what is it all to me"]
    changeset = Article.post_changeset(%Article{}, headers, body)
    assert changeset.valid?
    Repo.insert! changeset

    article = Repo.get(Article, changeset.changes[:message_id]) |> Repo.preload(:groups)
    assert article.from == headers["From"]
    assert article.subject == headers["Subject"]
    assert article.content_type == headers["Content-Type"]
    assert String.split(article.body, "\n") == body
    assert article.groups == [group]
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
