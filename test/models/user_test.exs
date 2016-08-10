defmodule Athel.UserTest do
  use Athel.ModelCase

  alias Athel.User

  @valid_attrs %{username: "he_man",
                 email: "me@him.who",
                 encrypted_password: "knarly",
                 salt: "WHEN"}

  test "valid" do
    assert User.changeset(%User{}, @valid_attrs).valid?
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

end
