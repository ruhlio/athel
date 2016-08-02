defmodule Athel.Nntp.FormatTest do
  use ExUnit.Case, async: true

  import Athel.Nntp.Format
  alias Athel.Article
  alias Athel.Group

  test "multiline multiline" do
    assert format_multiline(~w(cat in the hat)) == "cat\r\nin\r\nthe\r\nhat\r\n.\r\n"
  end

  test "singleline multiline" do
    assert format_multiline(~w(HORSE)) == "HORSE\r\n.\r\n"
  end

  test "empty multiline" do
    assert format_multiline([]) == ".\r\n"
  end

  test "article" do
    article = create_article()
    assert format_article(article) == "Content-Type: text/plain\r\nDate: 04 May 2016 03:02:01 -0500\r\nFrom: Me\r\nMessage-ID: <123@test.com>\r\nNewsgroups: fun.times,blow.away\r\nReferences: <547@heav.en>\r\nSubject: Talking to myself\r\n\r\nhow was your day?\r\nyou're too kind to ask\r\n"
  end

  test "article without optional fields" do
    article = %{create_article() | reference: nil, from: nil}
    assert format_article(article) == "Content-Type: text/plain\r\nDate: 04 May 2016 03:02:01 -0500\r\nMessage-ID: <123@test.com>\r\nNewsgroups: fun.times,blow.away\r\nSubject: Talking to myself\r\n\r\nhow was your day?\r\nyou're too kind to ask\r\n" 
  end

  test "group" do
    group = format_group %Group {
      name: "infected.binary",
      status: "y",
      low_watermark: 2,
      high_watermark: 333,
    }
    assert group == "infected.binary 333 2 y"
  end

  defp create_article do
    groups = [
      %Group {
        name: "fun.times",
        status: "y",
        low_watermark: 0,
        high_watermark: 0
      },
      %Group {
        name: "blow.away",
        status: "m",
        low_watermark: 0,
        high_watermark: 0
      }
    ]
    %Article {
      message_id: "123@test.com",
      from: "Me",
      subject: "Talking to myself",
      date: Timex.to_datetime({{2016, 5, 4}, {3, 2, 1}}, "America/Chicago"),
      reference: "547@heav.en",
      content_type: "text/plain",
      groups: groups,
      body: "how was your day?\nyou're too kind to ask"
    }
  end
end
