defmodule Athel.Nntp.ParserTest do
  use ExUnit.Case, async: true

  import Athel.Nntp.Parser

  test "valid code line" do
    assert parse_code_line("203 all clear\r\n") == {:ok, {203, "all clear"}, ""}
  end

  test "code line missing newline" do
    assert parse_code_line("301 I smell bananas") == {:error, :line}
  end

  test "newline missing \\n" do
    assert parse_code_line("391 HEYO\r") == {:error, :line}
  end

  test "code too short" do
    assert parse_code_line("31 GET ME") == {:error, :code}
  end

  test "code too long" do
    assert parse_code_line("3124 GIRAFFE NECK") == {:error, :code}
  end

  test "non-numerical code" do
    assert parse_code_line("!@# ok") == {:error, :code}
  end

  test "valid multiline" do
    assert parse_multiline("hey\r\nthere\r\nparty\r\npeople\r\n.\r\n") == {:ok, ~w(hey there party people), ""}
  end

  test "valid escaped multiline" do
    assert parse_multiline("i put periods\r\n.. at the beginning\r\n.. of my lines\r\n.\r\n") == {:ok, ["i put periods", ". at the beginning", ". of my lines"], ""}
  end

  test "unescaped multiline" do
    assert parse_multiline("I DO\r\n.WHAT I WANT\r\n.\r\n") == {:error, :multiline}
  end

  test "unterminated multiline" do
    assert parse_multiline("I SMELL LONDON\r\nI SMELL FRANCE\r\nI SMELL AN UNTERMINATED MULTILINE\r\n") == {:error, :multiline}
  end

end
