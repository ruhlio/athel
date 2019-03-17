defmodule Athel.UserTest do
  use Athel.ModelCase

  alias Athel.User

  test "valid" do
    {:ok, hash} = Multihash.encode(:sha2_512, :crypto.hash(:sha512, "knarly"))
    attrs = %{email: "me@him.who",
              hashed_password: hash,
              salt: "WHENWILLIEVER",
              status: "active"}
    assert User.changeset(%User{}, attrs).valid?
  end

  test "username" do
    assert_invalid_format(%User{}, :username,
      ["as",
       "they go",
       "SPLELUNKADUNKINGWHAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAT"])
  end

  test "email" do
    assert_invalid_format(%User{}, :email,
      ["asd@sdf.p",
       "I'M GONNA@do.nothing",
       "cannot.feel@m@.legs"])

    superlong = fn -> "HA" end
    |> Stream.repeatedly()
    |> Enum.take(200)
    |> Enum.join
    assert_too_long(%User{}, :email, "#{superlong}@bob.com")
  end

  test "hashed password" do
    assert_invalid(%User{}, :hashed_password,
      [<<0xf>>, <<0x63, 0x22, 0x44>>], "invalid multihash")
  end

end
