defmodule Athel.AuthServiceTest do
  use Athel.ModelCase

  import Athel.AuthService

  setup do
    {:ok, user} = create_user("jimbo", "jimbo@thrilling.chilling", "cherrypie")
    {:ok, user: user}
  end

  test "create invalid user" do
    {:error, _} = create_user("mr blister", "who", "what")
  end

  test "login", %{user: user} do
    {:ok, logged_in_user} = login("jimbo", "cherrypie")
    assert user.username == logged_in_user.username
    refute user.salt == logged_in_user.salt

    assert login("jimbo", "HARDBODIES") == :invalid_credentials
    assert login("peeweeherman", "jeepers") == :invalid_credentials
  end

end
