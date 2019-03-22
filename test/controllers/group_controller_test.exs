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

  test "pagination", %{conn: conn} do
    Athel.ModelCase.setup_models(200)

    request = get conn, "/groups/fun.times"
    response = html_response(request, 200)
    for page <- 0..4 do
      assert response =~ "fun.times?page=#{page}"
    end
    assert response =~ "fun.times?page=13"
    assert count_instances(response, "Talking to myself") == 15

    request = get conn, "/groups/fun.times?page=13"
    response = html_response(request, 200)
    for page <- 9..13 do
      assert response =~ "fun.times?page=#{page}"
    end
    assert count_instances(response, "Talking to myself") == 5
  end

  test "pagination without enough articles to show all pages", %{conn: conn} do
    Athel.ModelCase.setup_models(32)

    request = get conn, "/groups/fun.times"
    response = html_response(request, 200)

    for page <- 0..2 do
      assert response =~ "fun.times?page=#{page}"
    end
    refute response =~ "fun.times?pages=3"

    request = get conn, "/groups/fun.times?page=1"
    response = html_response(request, 200)

    for page <- 0..2 do
      assert response =~ "fun.times?page=#{page}"
    end
    refute response =~ "fun.times?pages=3"
  end

  test "no pagination when too few articles", %{conn: conn} do
    Athel.ModelCase.setup_models(5)

    request = get conn, "/groups/fun.times"
    response = html_response(request, 200)

    refute response =~ "fun.times?page="
  end

  test "search", %{conn: conn} do
    Athel.ModelCase.setup_models(5)
    Repo.update_all from(a in Athel.Article, where: a.message_id == "01@test.com"),
      set: [subject: "Asphalt"]
    Athel.ArticleSearchIndex.update_view()

    request = get conn, "/groups/fun.times?query=asphalt"
    response = html_response(request, 200)
    assert response =~ "Asphalt"
    assert count_instances(response, "/articles") == 1

    request = get conn, "/groups/fun.times?query=OREODUNK"
    response = html_response(request, 200)
    assert count_instances(response, "/articles") == 0
  end

  test "doesn't show child articles", %{conn: conn} do
    Athel.ModelCase.setup_models(5)
    Repo.update_all from(a in Athel.Article, where: a.message_id == "01@test.com" or a.message_id == "02@test.com"),
      set: [subject: "Asphalt"]
    Repo.update_all from(a in Athel.Article, where: a.message_id == "02@test.com"),
      set: [parent_message_id: "01@test.com"]
    Athel.ArticleSearchIndex.update_view()

    request = get conn, "/groups/fun.times"
    response = html_response(request, 200)
    assert count_instances(response, "/articles") == 4

    request = get conn, "/groups/fun.times?query=asphalt"
    response = html_response(request, 200)
    assert count_instances(response, "/articles") == 1
  end

  defp create_group!() do
    Repo.insert!(%Group{
          name: "cool.runnings",
          description: "Get on up, it's bobsled time!",
          status: "y",
          low_watermark: 0,
          high_watermark: 0})
  end

  defp count_instances(string, match) do
    length(String.split(string, match)) - 1
  end
end
