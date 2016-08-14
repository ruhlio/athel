defmodule Athel.ModelCase do
  @moduledoc """
  This module defines the test case to be used by
  model tests.

  You may define functions here to be used as helpers in
  your model tests. See `errors_on/2`'s definition as reference.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Athel.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Athel.ModelCase
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Athel.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Athel.Repo, {:shared, self()})
    end

    :ok
  end

  @spec error(Changeset.t, atom) :: String.t
  def error(changeset, key) do
    {actual_message, _} = changeset.errors[key]
    actual_message
  end

  @spec assert_invalid(struct, atom, list | any, String.t) :: nil
  def assert_invalid(struct, attr, invalid_values, error_message) when is_list(invalid_values) do
    for value <- invalid_values do
      assert_invalid(struct, attr, value, error_message)
    end
  end

  def assert_invalid(struct, attr, invalid_value, error_message) do
    changeset = struct.__struct__.changeset(struct, %{attr => invalid_value})
    assert error(changeset, attr) =~ error_message
  end

  def assert_invalid_format(module, attr, invalid_values) do
    assert_invalid(module, attr, invalid_values, "has invalid format")
  end

  def assert_too_long(module, attr, invalid_values) do
    assert_invalid(module, attr, invalid_values, "should be at most")
  end

  @spec setup_models(non_neg_integer) :: Athel.Group.t
  def setup_models(article_count \\ 0) do
    group = Athel.Repo.insert! %Athel.Group {
      name: "fun.times",
      description: "Funners of the world unite",
      status: "y",
      low_watermark: 0,
      high_watermark: 0
    }

    for index <- 0..max(article_count - 1, 0) do
      changeset =
        Athel.Article.changeset(%Athel.Article{},
          %{
            message_id: "0#{index}@test.com",
            from: "Me",
            subject: "Talking to myself",
            date: Timex.now(),
            parent_message_id: nil,
            content_type: "text/plain",
            body: "LET'S ROCK OUT FOR JESUS & AMERICA"
          })
          |> Ecto.Changeset.put_assoc(:groups, [group])
      Athel.Repo.insert! changeset
    end

    group
  end

end
