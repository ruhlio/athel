defmodule Athel.NntpServiceTest do
  use Athel.ModelCase

  import Athel.NntpService
  alias Athel.{Article, Group}

  test "get groups" do
    setup_models()
    Repo.insert! %Group{
      name: "dude",
      description: "what",
      low_watermark: 0,
      high_watermark: 0,
      status: "y"
    }

    assert get_groups() |> Enum.map(&(&1.name)) == ["dude", "fun.times"]
  end

  test "get group" do
    setup_models()

    assert get_group("COSTANZA") == nil
    assert %Group{name: "fun.times"} = get_group("fun.times")
  end

  test "get article" do
    setup_models(2)

    article = Repo.get!(Article, "00@test.com")
    changeset = change(article, status: "banned")
    Repo.update!(changeset)
    assert get_article("asd") == nil
    assert get_article("01@test.com").message_id == "01@test.com"
  end

  test "get article by index" do
    group = setup_models(5)

    {index, article} = get_article_by_index(group, 2)
    assert {index, article.message_id} == {2, "02@test.com"}

    articles = get_article_by_index(group, 2, :infinity)
    assert message_ids(articles) == [
      {2, "02@test.com"},
      {3, "03@test.com"},
      {4, "04@test.com"}
    ]

    articles = get_article_by_index(group, 2, 4)
    assert message_ids(articles) == [
      {2, "02@test.com"},
      {3, "03@test.com"}
    ]

    articles = get_article_by_index(group, 7, 5)
    assert articles == []

    group = Repo.update! Group.changeset(group, %{low_watermark: 2})
    articles = get_article_by_index(group, 1, :infinity)
    assert message_ids(articles) == [
      {2, "02@test.com"},
      {3, "03@test.com"},
      {4, "04@test.com"}
    ]

    group = Repo.update! Group.changeset(group, %{low_watermark: 0})
    article = Repo.get!(Article, "02@test.com")
    changeset = change(article, status: "banned")
    Repo.update!(changeset)
    assert get_article_by_index(group, 0, :infinity) |> message_ids == [
      {0, "00@test.com"},
      {1, "01@test.com"},
      {3, "03@test.com"},
      {4, "04@test.com"}
    ]
  end

  test "post" do
    group = setup_models()

    {:error, changeset} = post_article(%{"Newsgroups" => "heyo"}, [])
    assert error(changeset, :groups) == "is invalid"

    {:error, changeset} = post_article(%{}, [])
    assert error(changeset, :groups) == "is invalid"

    {:error, changeset} = post_article(%{"References" => "nothing"}, [])
    assert error(changeset, :parent) == "is invalid"

    headers = %{
      "From" => "Triple One",
      "Subject" => "Colors",
      "Content-Type" => "text/plain",
      "Newsgroups" => "fun.times"
    }
    body = ["All I see are these colors", "we walk with distant lovers", "but really what is it all to me"]
    {:ok, posted_article} = post_article(headers, body)

    article = Repo.get(Article, posted_article.message_id) |> Repo.preload(:groups)
    assert article.from == headers["From"]
    assert article.subject == headers["Subject"]
    assert article.content_type == headers["Content-Type"]
    assert article.body == body
    assert article.groups == [group]
  end

  test "take" do
    setup_models()

    date = Timex.to_datetime({{2012, 7, 4}, {4, 51, 23}}, "Etc/GMT+6")
    headers = %{
      "Message-ID" => "<not@really.here>",
      "Date" => "Tue, 04 Jul 2012 04:51:23 -0600",
      "From" => "ur mum",
      "Subject" => "heehee",
      "Content-Type" => "text/plain",
      "Newsgroups" => "fun.times"
    }
    body = ["brass monkey"]
    {:ok, taken_article} = take_article(headers, body)

    assert taken_article.date == date
    assert taken_article.message_id == "not@really.here"
  end

  test "get new groups" do
    Repo.insert!(%Group {
          name: "old.timer",
          description: "I can smell the graveworms",
          low_watermark: 0,
          high_watermark: 0,
          status: "y",
          inserted_at: ~N[1969-12-31 23:59:59]})
    Repo.insert!(%Group {
          name: "young.whippersnapper",
          description: "I wanna be you fetish queen",
          low_watermark: 0,
          high_watermark: 0,
          status: "y",
          inserted_at: ~N[2012-03-04 05:55:55]})
    assert get_groups_created_after(~N[2010-04-05 22:22:22])
    |> Enum.map(&(&1.name)) == ["young.whippersnapper"]
  end

  defp message_ids(articles) do
    Enum.map(articles, fn {row, article} -> {row, article.message_id} end)
  end
end
