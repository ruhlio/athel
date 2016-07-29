defmodule Athel.Nntp.ParserTest do
  use ExUnit.Case, async: true

  import Athel.Nntp.Parser

  test "valid code line" do
    assert parse_code_line("203 all clear\r\n") == {:ok, {203, "all clear"}, ""}
  end

  test "incomplete newline" do
    assert parse_code_line("391 HEYO\r") == :need_more
  end

  test "invalid newline" do
    assert parse_code_line("404 SMELL YA LATER\r\a") == {:error, :line}
    assert parse_code_line("404 SMELL YA LATER\n") == {:error, :line}
  end

  test "code too short" do
    assert parse_code_line("31 GET ME") == {:error, :code}
  end

  test "code too long" do
    assert parse_code_line("3124 GIRAFFE NECK") == {:error, :code}
  end

  test "truncated code" do
    assert parse_code_line("12") == :need_more
  end

  test "truncated line" do
    assert parse_code_line("123 i could just") == :need_more
  end

  test "non-numerical code" do
    assert parse_code_line("!@# ok") == {:error, :code}
  end

  test "valid multiline" do
    multiline = parse_multiline("hey\r\nthere\r\nparty\r\npeople\r\n.\r\n")
    assert multiline == {:ok, ~w(hey there party people), ""}
  end

  test "valid escaped multiline" do
    multiline = parse_multiline("i put periods\r\n.. at the beginning\r\n.. of my lines\r\n.\r\n")
    assert multiline == {:ok, ["i put periods", ". at the beginning", ". of my lines"], ""}
  end

  test "unescaped multiline" do
    assert parse_multiline("I DO\r\n.WHAT I WANT\r\n.\r\n") == {:error, :multiline}
  end

  test "unterminated multiline" do
    multiline = parse_multiline("I SMELL LONDON\r\nI SMELL FRANCE\r\nI SMELL AN UNTERMINATED MULTILINE\r\n")
    assert multiline == :need_more
  end

  test "valid headers" do
    headers = parse_headers("Content-Type: funky/nasty\r\nBoogie-Nights: You missed that boat\r\n\r\n")
    assert headers == {:ok, %{"Content-Type" => "funky/nasty", "Boogie-Nights" => "You missed that boat"}, ""}
  end

  test "header name with whitespace" do
    assert parse_headers("OH YEAH: BROTHER\r\n\r\n") == {:error, :header_name}
  end

  test "unterminated headers" do
    assert parse_headers("this-train: is off the tracks\r\n") == :need_more
  end

  test "newline terminated header name" do
    assert parse_headers("i-just-cant-seem-to-ever-shut-my-piehole\r\n") == {:error, :header_name}
  end

  test "unterminated header name" do
    assert parse_headers("just-must-fuss") == :need_more
  end

  test "unterminated header value" do
    assert parse_headers("welcome: to the danger zone") == :need_more
  end

end
