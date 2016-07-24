defmodule Athel.PageControllerTest do
  use Athel.ConnCase, async: true

  test "GET /", %{conn: conn} do
    conn = get conn, "/"
    assert html_response(conn, 200) =~ "Welcome to Good Burger"
  end
end
