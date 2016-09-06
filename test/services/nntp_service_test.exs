defmodule Athel.NntpServiceTest do
  use Athel.ModelCase

  import Athel.NntpService
  alias Athel.{Group, Article}

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

    {:error, changeset} = post_article(%{"NEWSGROUPS" => "heyo"}, [])
    assert error(changeset, :groups) == "is invalid"

    {:error, changeset} = post_article(%{}, [])
    assert error(changeset, :groups) == "is invalid"

    {:error, changeset} = post_article(%{"REFERENCES" => "nothing"}, [])
    assert error(changeset, :parent) == "is invalid"

    headers = %{
      "FROM" => "Triple One",
      "SUBJECT" => "Colors",
      "CONTENT-TYPE" => "text/plain",
      "NEWSGROUPS" => "fun.times"
    }
    body = ["All I see are these colors", "we walk with distant lovers", "but really what is it all to me"]
    {:ok, posted_article} = post_article(headers, body)

    article = Repo.get(Article, posted_article.message_id) |> Repo.preload(:groups)
    assert article.from == headers["FROM"]
    assert article.subject == headers["SUBJECT"]
    assert article.content_type == headers["CONTENT-TYPE"]
    assert article.body == body
    assert article.groups == [group]
  end

  test "post with attachments" do
    setup_models()

    headers =
      %{"SUBJECT" => "gnarly",
        "FROM" => "Chef Mandude <surferdude88@hotmail.com>",
        "NEWSGROUPS" => "fun.times",
        "MIME-VERSION" => "1.0",
        "CONTENT-TYPE" => {"multipart/mixed", %{"boundary" => "surfsup"}}}
    body =
      ["--surfsup",
       "Content-Transfer-Encoding: base64",
       "Content-Disposition: attachment; filename=\"phatwave.jpg\"",
       "",
       "TkFVR0hU",
       "--surfsup--"]
    {:ok, article} = post_article(headers, body)

    assert article.body == []
    [attachment] = article.attachments
    assert attachment.filename == "phatwave.jpg"
    assert attachment.content == "NAUGHT"
  end

  test "post takes first attachment content as body if it is text without filename" do
    setup_models()

    headers =
      %{"SUBJECT" => "gnarly",
        "FROM" => "Chef Mandude <surferdude88@hotmail.com>",
        "NEWSGROUPS" => "fun.times",
        "MIME-VERSION" => "1.0",
        "CONTENT-TYPE" => {"multipart/mixed", %{"boundary" => "surfsup"}}}
    single_attachment_body =
      ["--surfsup",
       "Content-Transfer-Encoding: base64",
       "",
       "Q2FuJ3QgZ2V0IG15DQpsaW5lIGVuZGluZ3MKY29uc2lzdGVudA1pIHF1aXQ=",
       "--surfsup--"]
    multi_attachment_body =
      ["--surfsup",
       "Content-Transfer-Encoding: base64",
       "",
       "Q2FuJ3QgZ2V0IG15DQpsaW5lIGVuZGluZ3MKY29uc2lzdGVudA1pIHF1aXQ=",
       "--surfsup",
       "Content-Transfer-Encoding: base64",
       "Content-Disposition: attachment; filename=\"turbo_killer.gif\"",
       "",
       "c2htb2tpbic=",
       "--surfsup--"]
    {:ok, single_attachment_article} = post_article(headers, single_attachment_body)
    {:ok, multi_attachment_article} = post_article(headers, multi_attachment_body)

    assert single_attachment_article.body == ["Can't get my", "line endings", "consistent", "i quit"]
    assert multi_attachment_article.body == single_attachment_article.body

    assert single_attachment_article.attachments == []
    [attachment] = multi_attachment_article.attachments
    assert attachment.filename == "turbo_killer.gif"
    assert attachment.content == "shmokin'"
  end

  test "take" do
    setup_models()

    date = Timex.to_datetime({{2012, 7, 4}, {4, 51, 23}}, "Etc/GMT+6")
    headers = %{
      "MESSAGE-ID" => "<not@really.here>",
      "DATE" => "Tue, 04 Jul 2012 04:51:23 -0600",
      "FROM" => "ur mum",
      "SUBJECT" => "heehee",
      "CONTENT-TYPE" => "text/plain",
      "NEWSGROUPS" => "fun.times"
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

  test "get new articles" do
    group = setup_models()

    articles = [
      %{message_id: "good@old.boys", date: ~N[1969-12-31 23:59:59]},
      %{message_id: "cherry@burger.pies", date: ~N[2012-03-04 05:55:55]}
    ]
    for article <- articles do
      changeset = Article.changeset(%Article{}, Map.merge(article,
        %{from: "whoever",
          subject: "whatever",
          body: ["however"],
          content_type: "text/plain",
          status: "active"}))
      |> put_assoc(:groups, [group])
      Repo.insert!(changeset)
    end

    assert get_articles_created_after("fun.times", ~N[2010-04-05 22:22:22])
    |> Enum.map(&(&1.message_id)) == ["cherry@burger.pies"]
    assert get_articles_created_after("bad.times", ~N[2010-04-05 22:22:22]) == []
  end

  defp message_ids(articles) do
    Enum.map(articles, fn {row, article} -> {row, article.message_id} end)
  end
end
