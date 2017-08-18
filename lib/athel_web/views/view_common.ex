defmodule AthelWeb.ViewCommon do
  use Timex

  def format_date(date) do
    Timex.format!(date, "%a, %d %b %Y %T %z", :strftime)
  end

  def error_class(changeset, input) do
    if changeset.errors[input] do
      "input-error"
    else
      ""
    end
  end
end
