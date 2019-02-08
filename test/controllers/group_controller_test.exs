defmodule AthelWeb.GroupControllerTest do
  use AthelWeb.ConnCase
  alias Athel.Group
  alias Athel.Repo

  test "index no groups", %{conn: conn} do
    conn = get conn, "/groups"
    resp = html_response(conn, 200)
    assert resp =~ "Groups"
    assert resp =~ "No groups"
  end

  test "index groups", %{conn: conn} do
    create_group!()
    conn = get conn, "/groups"
    assert html_response(conn, 200) =~ "cool.runnings"
  end

  test "show group with no articles" do
    create_group!()
    conn = get build_conn(), "/groups/cool.runnings"
    resp = html_response(conn, 200)
    assert resp =~ "cool.runnings"
    assert resp =~ "No articles"
  end

  # test "post new topic article to group" do
  #   create_group!()
  #   article = [subject: "ey", from: "your mom", body: "pastor's dishpole"]
  #   conn = post build_conn(), "/groups/cool.runnings", article: article
  #   html_response(conn, 302)

  #   conn = get build_conn(), "/groups/cool.runnings"
  #   resp = html_response(conn, 200)
  #   assert resp =~ "ey"
  # end

  test "post invalid topic article to group" do
    create_group!()
    article = [subject: "", from: "", body: "IT WAS ME ALL ALONG, AUSTIN"]
    conn = post build_conn(), "/groups/cool.runnings", article: article
    resp = html_response(conn, 200)
    resp =~ "Please correct errors"
  end

  defp create_group!() do
    Repo.insert!(%Group{
          name: "cool.runnings",
          description: "Get on up, it's bobsled time!",
          status: "y",
          low_watermark: 0,
          high_watermark: 0})
  end
end
