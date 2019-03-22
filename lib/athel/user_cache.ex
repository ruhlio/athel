defmodule Athel.UserCache do
  use GenServer

  # API

  def start_link(), do: start_link([])
  def start_link([]) do
    GenServer.start_link(__MODULE__, :ok, name: UserCache)
  end

  def get(email) do
    GenServer.call(UserCache, {:get, email})
  end

  def put(user) do
    GenServer.cast(UserCache, {:put, user})
  end

  # Impl

  @impl true
  def init(:ok) do
    {:ok, %{}, {:continue, :load_users}}
  end

  @impl true
  def handle_continue(:load_users, _state) do
    users = %{}
      # Athel.User
    # |> Athel.Repo.all()
    # |> Enum.reduce(%{}, fn user, acc ->
    #   loaded_user = %{user | decoded_public_key: load_key(user.public_key)}
    #   Map.put(acc, user.email, loaded_user)
    # end)

    {:noreply, users}
  end

  @impl true
  def handle_call({:get, email}, _from, users) do
    {:reply, Map.get(users, email), users}
  end

  @impl true
  def handle_cast({:put, user}, users) do
    loaded_user = %{user | decoded_public_key: load_key(user.public_key)}
    {:noreply, Map.put(users, user.email, loaded_user)}
  end

  defp load_key(key) do
    [pem] = :public_key.pem_decode(key)
    :public_key.pem_entry_decode(pem)
  end

end
