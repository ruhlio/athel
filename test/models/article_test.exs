defmodule Athel.ArticleTest do
  use Athel.ModelCase

  alias Athel.Article

  @valid_attrs %{message_id: "123@banana", body: "some content", content_type: "some content", date: Timex.now(), from: "some content", parent: nil, subject: "some content", status: "active"}
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

    changeset = Article.changeset(%Article{}, %{@valid_attrs | message_id: "<with@angle.brackets>"})
    assert changeset.valid?
    assert changeset.changes[:message_id] == "with@angle.brackets"
  end

  test "string date" do
    changeset = Article.changeset(%Article{}, %{@valid_attrs | date: "Tue, 04 Jul 2012 04:51:23 -0500"})
    assert changeset.changes[:date] == Timex.to_datetime({{2012, 7, 4}, {9, 51, 23}}, "Etc/UTC")
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

  test "status" do
    assert_invalid(%Article{}, :status, "decimated", "is invalid")
  end

  test "joins list bodies" do
    changeset = Article.changeset(%Article{}, %{@valid_attrs | body: ["multiline", "fantasy"]})
    assert changeset.valid?
    assert changeset.changes[:body] == "multiline\nfantasy"
  end

end
