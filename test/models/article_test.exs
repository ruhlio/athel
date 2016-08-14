defmodule Athel.ArticleTest do
  use Athel.ModelCase

  alias Athel.Article

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

end
