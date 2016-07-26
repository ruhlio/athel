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

end
