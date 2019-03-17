defmodule Athel.AuthService do
  alias Ecto.Changeset
  alias Athel.Repo
  alias Athel.User

  @spec create_user(String.t, String.t) :: {:ok, User.t} | {:error, Changeset.t}
  def create_user(email, password) do
    salt = create_salt()
    changeset = User.changeset(%User{},
      %{email: email,
        salt: salt,
        hashed_password: hash_password(password, salt),
        status: "active"})
    Repo.insert(changeset)
  end

  @spec login(String.t, String.t) :: {:ok, User.t} | :invalid_credentials
  def login(email, password) do
    case Repo.get_by(User, email: email) do
      nil -> :invalid_credentials
      user ->
        if hash_password(password, user.salt) == user.hashed_password do
          {:ok, update_login(user, password)}
        else
          :invalid_credentials
        end
    end

  end

  defp update_login(user, password) do
    new_salt = create_salt()
    user = Changeset.change user,
      salt: new_salt,
      hashed_password: hash_password(password, new_salt)
    Repo.update!(user)
  end

  defp create_salt do
    :crypto.strong_rand_bytes(32)
  end

  defp hash_password(password, salt) do
    hash = :crypto.hash(:sha512, password <> salt)
    {:ok, multihash} = Multihash.encode(:sha2_512, hash)
    multihash
  end

end
