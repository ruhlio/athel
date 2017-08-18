defmodule AthelWeb.PageController do
  use AthelWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
