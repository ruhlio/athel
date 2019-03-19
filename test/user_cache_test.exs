defmodule Athel.UserCacheTest do
  use ExUnit.Case
  alias Athel.{UserCache, User, TestData}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Athel.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Athel.Repo, {:shared, self()})

    :ok
  end

  test "put" do
    user = %User{email: "santa@north.pole", status: "active", public_key: TestData.public_key}
    UserCache.put(user)
    stored_user = UserCache.get("santa@north.pole")
    assert stored_user.email == "santa@north.pole"
    {key_type, _, _} = stored_user.decoded_public_key
    assert key_type == :RSAPublicKey
  end
end
