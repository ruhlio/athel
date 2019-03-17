defmodule Athel.AuthServiceTest do
  use Athel.ModelCase
  alias Athel.AuthService

  setup do
    {:ok, user} = AuthService.create_user("jimbo@thrilling.chilling", "cherrypie")
    {:ok, user: user}
  end

  test "create invalid user" do
    {:error, _} = AuthService.create_user("who", "what")
  end

  test "login", %{user: user} do
    {:ok, logged_in_user} = AuthService.login("jimbo@thrilling.chilling", "cherrypie")
    assert user.username == logged_in_user.username
    refute user.salt == logged_in_user.salt

    assert AuthService.login("jimbo@thrilling.chilling", "HARDBODIES") == :invalid_credentials
    assert AuthService.login("peeweeherman", "jeepers") == :invalid_credentials
  end

end
