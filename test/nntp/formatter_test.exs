defmodule Athel.Nntp.FormatterTest do
  use ExUnit.Case, async: true

  import Athel.Nntp.Formatter

  test "multiline multiline" do
    assert format_multiline(~w(cat in the hat)) == "cat\r\nin\r\nthe\r\nhat\r\n.\r\n"
  end

  test "singleline multiline" do
    assert format_multiline(~w(HORSE)) == "HORSE\r\n.\r\n"
  end

  test "empty multiline" do
    assert format_multiline([]) == ".\r\n"
  end
end
