defmodule Athel.AuthServiceTest do
  use Athel.ModelCase
  alias Athel.{AuthService, UserCache, TestData}

  @signature "6E0FCFD3028899FE8BE11F44FC931FCE3435B8A6D0565AACDB6DFE28B23BB3C31030E1FE481D2070EFB837697287488ED0E4CEF061D748DE7F733A05C9589AE08A60C7784CE383106979BB0E9F2872FC0B5B9E834DA7E9943CF2687AF5E55FCC6FF77C7160FBC0B06ECFAE70DD98EA22AAE8177832F78C6F146A8F1E2EFF43C469CCEF9D9D68E125729517C4DB04170A979C164B34BD8A70103D6903EC5C2D396C255C23000C3538005F5B21D8A7A09A354A07BD775325D1F21A83E7A042BA9796B17B25DE4D9BC2AF8D9058863C88B7749B9FC52F187AEB9C05F37E8512AB7B7CC081D48B517A7A91DEE9527B3E65BC50B8AEE41374F91283CF1488FDDECEAA"

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

  test "verify", %{user: user} do
    user = %{user | public_key: TestData.public_key}
    UserCache.put(user)

    assert AuthService.verify("nobody@example.com", "416", "asd") == false
    assert AuthService.verify(user.email, "416", "asd") == false
    assert AuthService.verify(user.email, @signature, "And now we have to say goodbye\n") == true
  end

end
