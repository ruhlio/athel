defmodule Athel.UserCacheTest do
  use ExUnit.Case
  alias Athel.{UserCache, User}

  @public_key """
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArqZrJaCElI7RnTP3qrSs
MoM9LEgRQhmJK5I5p9tBaGPRKXSBZ072NREHM+z19KCCItnLbPXp4DKPJt8BGHuM
lFq3jz+RSwc8I6E10NpLcHsdPftC/X/5qVCNSol6rjQxPWNzXdF5xmDURQA5svop
VWbclv3uJaDg8sORDwcedUkEtkEZCRkHR8a3ZO2vjhIRPqPuh1keRG0EK4wypXnM
dlyQC3Ci3cnXQQgj3HsJCuqdt2mN7TNQLlGNqLm/DufrkBS22Kr6SV1M0lw9n/CI
/lBG9i0WOiKmJZS2ka5sXEP3rtTJprl5i4yNCjjAmXdmAL8PJ3cs4tHWt2BsFOXQ
AwIDAQAB
-----END PUBLIC KEY-----
"""

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Athel.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Athel.Repo, {:shared, self()})

    :ok
  end

  test "put" do
    user = %User{email: "santa@north.pole", status: "active", public_key: @public_key}
    UserCache.put(user)
    stored_user = UserCache.get("santa@north.pole")
    assert stored_user.email == "santa@north.pole"
    {key_type, _, _} = stored_user.decoded_public_key
    assert key_type == :RSAPublicKey
  end
end
