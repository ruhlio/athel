defmodule Athel.AttachmentTest do
  use Athel.ModelCase

  alias Athel.Attachment

  @valid_attrs %{content: "some content", type: "some content"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Attachment.changeset(%Attachment{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Attachment.changeset(%Attachment{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "hashes content" do
    {:ok, hash} = Multihash.encode(:sha1,
      <<183, 10, 51, 217, 73, 25, 65, 174, 198, 46, 152, 98, 8, 119, 198, 138, 45, 97,
      114, 81>>)
    changeset = Attachment.changeset(%Attachment{},
      %{@valid_attrs | content: "hello, sailor"})
    assert changeset.changes[:hash] == hash
  end

end
