defmodule Athel.Nntp.Defs do
  defmacro check_argument_count(command_name, count) do
    quote do
      def handle_call({unquote(command_name), args}, _from, state) when length(args) > unquote(count) do
        {:reply, {:continue, {501, "Too many arguments"}}, state}
      end
    end
  end

end
