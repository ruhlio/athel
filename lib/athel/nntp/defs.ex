defmodule Athel.Nntp.Defs do

  defmacro command(name, function, opts) do
    max_args = Keyword.get(opts, :max_args, 0)
    auth = Keyword.get(opts, :auth, [required: false])
    unauthorized_response = Keyword.get(auth, :response, {483, "Unauthorized"})

    max_args_clause = quote do
      length(args) > unquote(max_args) ->
        {:reply, {:continue, {501, "Too many arguments"}}, state}
    end

    auth_clause = quote do
      !is_authenticated(state) ->
        Logger.info(
          "Access denied for #{get_username(state)}@#{unquote(name)}")
        {:reply, {:continue, unquote(unauthorized_response)}, state}
    end

    action_clause = quote do
      true ->
        try do
          case __MODULE__.unquote(function)(args, state) do
            {action, response} ->
              {:reply, {action, response}, state}
            {action, response, state_updates} ->
              new_state = Map.merge(state, state_updates)
              {:reply, {action, response}, new_state}
          end
        rescue
          _ in FunctionClauseError ->
            Logger.info(
              "Invalid arguments passed to '#{unquote(name)}': #{inspect args}")
            {:reply, {:error, {501, "Invalid #{unquote(name)} arguments"}}, state}
        end
    end

    clauses = List.flatten(if auth[:required] do
      [max_args_clause, auth_clause, action_clause]
    else
      [max_args_clause, action_clause]
    end)

    quote do
      def handle_call({unquote(name), args}, _sender, state) do
        # credo:disable-for-next-line Credo.Check.Refactor.CondStatements
        cond do
          unquote(clauses)
        end
      end
    end

  end

  def is_authenticated(%{authentication: %Athel.User{}}), do: true
  def is_authenticated(_), do: false

  def get_username(%{authentication: %Athel.User{email: email}}) do
    "user #{email}"
  end
  def get_username(_), do: "unauthorized client"

end
