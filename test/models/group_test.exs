defmodule Athel.GroupTest do
  use Athel.ModelCase

  alias Athel.Group

  @valid_attrs %{high_watermark: 42, low_watermark: 42, name: "fun.times", status: "m", description: "OOSE OOSE"}
  @invalid_attrs %{high_watermark: -1, low_watermark: -1, name: "yo la tengo", status: "BANANAPANIC"}

  test "changeset with valid attributes" do
    changeset = Group.changeset(%Group{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Group.changeset(%Group{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "name format" do
    changeset = Group.changeset(%Group{}, @valid_attrs)
    assert changeset.valid?

    changeset = Group.changeset(%Group{}, %{@valid_attrs | name: "MR. BRIGGS"})
    assert changeset.errors[:name] == {"has invalid format", [validation: :format]}
  end

  test "name uniqueness" do
    changeset = Group.changeset(%Group{}, @valid_attrs)
    Repo.insert!(changeset)

    changeset = Group.changeset(%Group{}, @valid_attrs)
    {:error, changeset} = Repo.insert(changeset)
    assert changeset.errors[:name] == {"has already been taken", []}
  end
end
