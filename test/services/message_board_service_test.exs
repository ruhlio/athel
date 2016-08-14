defmodule Athel.MessageBoardServiceTest do
  use Athel.ModelCase

  import Athel.MessageBoardService
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

  test "get article" do
    setup_models(1)

    assert get_article("asd") == nil
    assert get_article("00@test.com").message_id == "00@test.com"
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
    assert String.split(article.body, "\n") == body
    assert article.groups == [group]
  end

  defp message_ids(articles) do
    Enum.map(articles, fn {row, article} -> {row, article.message_id} end)
  end
end
