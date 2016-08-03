defmodule Athel.ArticleTest do
  use Athel.ModelCase

  alias Athel.Article

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
end
