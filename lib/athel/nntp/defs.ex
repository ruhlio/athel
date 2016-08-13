defmodule Athel.Nntp.Defs do
  defmacro check_argument_count(command_name, count) do
    quote do
      def handle_call({unquote(command_name), args}, _sender, state) when length(args) > unquote(count) do
        {:reply, {:continue, {501, "Too many arguments"}}, state}
      end
    end
  end

  defmacro command(name, function, opts) do
    max_args = Keyword.get(opts, :max_args, 0)
    auth = Keyword.get(opts, :auth, [required: false])

    max_args_clause = quote do
      length(args) > unquote(max_args) ->
        {:reply, {:continue, {501, "Too many arguments"}}, state}
    end

    auth_clause = quote do
      !is_authenticated(state) ->
        {:reply, {:continue, unquote(auth[:response])}, state}
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
            Logger.info("Invalid arguments passed to '#{unquote(name)}': #{inspect args}")
            {:reply, {:error, {501, "Invalid #{unquote(name)} arguments"}}, state}
        end
    end

    clauses = if auth[:required] do
      [max_args_clause, auth_clause, action_clause]
    else
      [max_args_clause, action_clause]
    end |> List.flatten

    quote do
      def handle_call({unquote(name), args}, _sender, state) do
        cond do
          unquote(clauses)
        end
      end
    end

  end

  def is_authenticated(%{authentication: %Athel.User{}}), do: true
  def is_authenticated(_), do: false

end
