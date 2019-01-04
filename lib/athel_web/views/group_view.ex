defmodule AthelWeb.GroupView do
  use AthelWeb, :view

  def title("show.html", assigns) do
    assigns.group.name
  end
  def title(_t, _) do
    "Groups"
  end
end
