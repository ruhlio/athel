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

  @doc """
  Helper for returning list of errors in a struct when given certain data.

  ## Examples

  Given a User schema that lists `:name` as a required field and validates
  `:password` to be safe, it would return:

      iex> errors_on(%User{}, %{password: "password"})
      [password: "is unsafe", name: "is blank"]

  You could then write your assertion like:

      assert {:password, "is unsafe"} in errors_on(%User{}, %{password: "password"})

  You can also create the changeset manually and retrieve the errors
  field directly:

      iex> changeset = User.changeset(%User{}, password: "password")
      iex> {:password, "is unsafe"} in changeset.errors
      true
  """
  def errors_on(struct, data) do
    struct.__struct__.changeset(struct, data)
    |> Ecto.Changeset.traverse_errors(&Athel.ErrorHelpers.translate_error/1)
    |> Enum.flat_map(fn {key, errors} -> for msg <- errors, do: {key, msg} end)
  end

  def setup_models(article_count) do
    group = Athel.Repo.insert! %Athel.Group {
      name: "fun.times",
      description: "Funners of the world unite",
      status: "y",
      low_watermark: 0,
      high_watermark: 0
    }

    for index <- 0..(article_count - 1) do
      changeset =
        Athel.Article.changeset(%Athel.Article{},
          %{
            message_id: "0#{index}@test.com",
            from: "Me",
            subject: "Talking to myself",
            date: Timex.now(),
            reference: nil,
            content_type: "text/plain",
            body: "LET'S ROCK OUT FOR JESUS & AMERICA"
          })
          |> Ecto.Changeset.put_assoc(:groups, [group])
      Athel.Repo.insert! changeset
    end

    group
  end

end
