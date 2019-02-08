defmodule Athel.Nntp.FormatTest do
  use ExUnit.Case, async: true

  alias Athel.Nntp.Formattable
  alias Athel.{Group, Article, Attachment}

  test "multiline multiline" do
    assert format(~w(cat in the hat)) == "cat\r\nin\r\nthe\r\nhat\r\n.\r\n"
  end

  test "singleline multiline" do
    assert format(~w(HORSE)) == "HORSE\r\n.\r\n"
  end

  test "empty multiline" do
    assert format([]) == ".\r\n"
  end

  test "multiline with non-binary lines" do
    assert format(1..5) == "1\r\n2\r\n3\r\n4\r\n5\r\n.\r\n"
  end

  test "article" do
    article = create_article()
    assert format(article) == "Content-Type: text/plain\r\nDate: Wed, 04 May 2016 03:02:01 -0500\r\nFrom: Me\r\nMessage-ID: <123@test.com>\r\nNewsgroups: fun.times,blow.away\r\nReferences: <547@heav.en>\r\nSubject: Talking to myself\r\n\r\nhow was your day?\r\nyou're too kind to ask\r\n.\r\n"
  end

  test "article without optional fields" do
    article = %{create_article() | parent_message_id: nil, from: nil, date: nil}
    assert format(article) == "Content-Type: text/plain\r\nMessage-ID: <123@test.com>\r\nNewsgroups: fun.times,blow.away\r\nSubject: Talking to myself\r\n\r\nhow was your day?\r\nyou're too kind to ask\r\n.\r\n"
  end

  test "plain attachment" do
    attachment =
      %Attachment{type: "text/plain",
                  content: "That's a much more interesting story"}
    assert format(attachment) == "Content-Transfer-Encoding: base64\r\nContent-Type: text/plain\r\n\r\nVGhhdCdzIGEgbXVjaCBtb3JlIGludGVyZXN0aW5nIHN0b3J5\r\n"
  end

  test "file attachment" do
    attachment =
      %Attachment{type: "text/plain",
                  filename: "cool.txt",
                  content: "That's a much more interesting story"}
    assert format(attachment) == "Content-Disposition: attachment, filename=\"cool.txt\"\r\nContent-Transfer-Encoding: base64\r\nContent-Type: text/plain\r\n\r\nVGhhdCdzIGEgbXVjaCBtb3JlIGludGVyZXN0aW5nIHN0b3J5\r\n"
  end

  test "article with attachments" do
    attachments = [%Attachment{type: "text/plain", content: "Motorcycles"},
                   %Attachment{type: "text/plain", content: "Big rigs"}]
    article = %{create_article() | attachments: attachments}
    result = format(article)
    [_, boundary] = Regex.run ~r/boundary="(.*)"\r\n/m, result
    [_, body] = Regex.run ~r/\r\n\r\n(.*)\z/ms, result
    assert body == "how was your day?\r\nyou're too kind to ask\r\n\r\n--#{boundary}Content-Transfer-Encoding: base64\r\nContent-Type: text/plain\r\n\r\nTW90b3JjeWNsZXM=\r\n\r\n--#{boundary}Content-Transfer-Encoding: base64\r\nContent-Type: text/plain\r\n\r\nQmlnIHJpZ3M=\r\n\r\n--#{boundary}--\r\n.\r\n"
  end

  test "header names" do
    # small erlang maps have sorted entries
    headers = %{"MESSAGE-ID" => "123@example.com",
                "PARAMETERS" => %{value: "text/plain",
                                  params: %{"CHARSET" => "UTF-8",
                                            "SPACES" => "WHERE ARE\tTHEY"}},
                "ARRAY" => ["alchemist", "test", "report"],
                "KEBAB-CASE" => "shawarma"}
    assert format(headers) == "Array: alchemist\r\nArray: test\r\nArray: report\r\nKebab-Case: shawarma\r\nMessage-ID: 123@example.com\r\nParameters: text/plain; charset=UTF-8; spaces=\"WHERE ARE\tTHEY\"\r\n\r\n"
  end

  defp format(formattable) do
    formattable |> Formattable.format |> IO.iodata_to_binary
  end

  defp create_article do
    groups =
      [%Group{name: "fun.times",
              status: "y",
              low_watermark: 0,
              high_watermark: 0},
       %Group{name: "blow.away",
              status: "m",
              low_watermark: 0,
              high_watermark: 0}]

    %Article{message_id: "123@test.com",
             from: "Me",
             subject: "Talking to myself",
             date: Timex.to_datetime({{2016, 5, 4}, {3, 2, 1}}, "America/Chicago"),
             headers: %{},
             parent_message_id: "547@heav.en",
             content_type: "text/plain",
             groups: groups,
             attachments: [],
             body: "how was your day?\nyou're too kind to ask"}
  end
end
