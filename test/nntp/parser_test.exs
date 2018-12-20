defmodule Athel.Nntp.ParserTest do
  use ExUnit.Case, async: true

  import Athel.Nntp.Parser

  test "code and multiline" do
    input = "215 Order of fields in overview database\r\nSubject:\r\nFrom:\r\nDate:\r\nMessage-ID:\r\nReferences:\r\nBytes:\r\nLines:\r\nXref:full\r\n.\r\n"
    {:ok, {215, "Order of fields in overview database"}, rest} = parse_code_line(input)
    assert {:ok, ["Subject:", "From:", "Date:", "Message-ID:", "References:", "Bytes:", "Lines:", "Xref:full"], ""} == parse_multiline(rest)
  end

  test "valid code line" do
    assert parse_code_line(["203 all clear", "\r\n"]) == {:ok, {203, "all clear"}, ""}
  end

  test "incomplete newline" do
    {:need_more, {:line, acc, 391}} = parse_code_line("391 HEYO\r")
    assert IO.iodata_to_binary(acc) == "HEYO\r"
  end

  test "invalid newline" do
    assert parse_code_line("404 SMELL YA LATER\r\a") == {:error, :line}
    assert parse_code_line("404 SMELL YA LATER\n") == {:error, :line}
  end

  test "newline split across inputs" do
    {:need_more, good_state} = parse_code_line("404 WHADDUP\r")
    {:need_more, bad_state} = parse_code_line("404 WHADDUP")
    assert parse_code_line("\nmore", good_state) == {:ok, {404, "WHADDUP"}, "more"}
    assert parse_code_line("\nmore", bad_state) == {:error, :line}
  end

  test "code too short" do
    assert parse_code_line("31 GET ME") == {:error, :code}
  end

  test "code too long" do
    assert parse_code_line("3124 GIRAFFE NECK") == {:error, :code}
  end

  test "truncated code" do
    {:need_more, {:code, {acc, count}}} = parse_code_line("12")
    assert IO.iodata_to_binary(acc) == "12"
    assert count == 2
  end

  test "truncated line" do
    {:need_more, {:line, acc, code}} = parse_code_line("123 i could just")
    assert code == 123
    assert IO.iodata_to_binary(acc) == "i could just"
  end

  test "non-numerical code" do
    assert parse_code_line("!@# ok") == {:error, :code}
  end

  test "valid multiline" do
    multiline = parse_multiline(["hey\r\nthere\r\nparty\r\npeople\r\n", ".\r\n"])
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
    {:need_more, {line_acc, acc}} = parse_multiline("I SMELL LONDON\r\nI SMELL FRANCE\r\nI SMELL AN UNTERMINATED MULTILINE\r\nwut")
    assert IO.iodata_to_binary(line_acc) == "wut"
    assert acc == ["I SMELL AN UNTERMINATED MULTILINE", "I SMELL FRANCE", "I SMELL LONDON"]
  end

  test "valid headers" do
    headers = parse_headers(["Content-Type: funky/nasty\r\nBoogie-Nights: You missed that boat\r\n", "\r\n"])
    assert headers == {:ok,
                       %{"CONTENT-TYPE" => "funky/nasty",
                         "BOOGIE-NIGHTS" => "You missed that boat"},
                       ""}
  end

  test "multiline duplicate headers" do
    input = "References: <uadloawcn.fsf@assurancetourix.xs4all.nl> <m31y6z61sk.fsf@quimbies.gnus.org>\r
    <uadldpsph.fsf@assurancetourix.xs4all.nl>\r
    <m3of9t1mj8.fsf@quimbies.gnus.org>\r
    <uelap30l9.fsf@assurancetourix.xs4all.nl>\r
Original-Received: from quimby.gnus.org ([80.91.224.244])\r
	  by main.gmane.org with esmtp (Exim 3.35 #1 (Debian))\r
	  id 1827JK-0006HD-00\r
	  for <gmane-discuss-account@main.gmane.org>; Thu, 17 Oct 2002 11:51:22 +0200\r
Original-Received: from hawk.netfonds.no ([80.91.224.246])\r
	  by quimby.gnus.org with esmtp (Exim 3.12 #1 (Debian))\r
	  id 1828BC-0005rd-00\r
	  for <gmane-discuss-account@quimby.gnus.org>; Thu, 17 Oct 2002 12:47:02 +0200\r\n\r\n"

    assert parse_headers(input) == {:ok,
                      %{"REFERENCES" => "<uadloawcn.fsf@assurancetourix.xs4all.nl> <m31y6z61sk.fsf@quimbies.gnus.org> <uadldpsph.fsf@assurancetourix.xs4all.nl> <m3of9t1mj8.fsf@quimbies.gnus.org> <uelap30l9.fsf@assurancetourix.xs4all.nl>",
                        "ORIGINAL-RECEIVED" => [
                          "from hawk.netfonds.no ([80.91.224.246]) by quimby.gnus.org with esmtp (Exim 3.12 #1 (Debian)) id 1828BC-0005rd-00 for <gmane-discuss-account@quimby.gnus.org>; Thu, 17 Oct 2002 12:47:02 +0200",
                          "from quimby.gnus.org ([80.91.224.244]) by main.gmane.org with esmtp (Exim 3.35 #1 (Debian)) id 1827JK-0006HD-00 for <gmane-discuss-account@main.gmane.org>; Thu, 17 Oct 2002 11:51:22 +0200"
                        ]
                      }, ""}
  end

  test "header value with parameters" do
    result = parse_headers(
      ["Content-Type: attachment; boundary=hearsay; pants=off\r\n",
       "\r\n"])
    assert result == {:ok,
                      %{"CONTENT-TYPE" =>
                        {"attachment",
                         %{"boundary" => "hearsay",
                           "pants" => "off"}}},
                      ""}
  end

  test "header with params followed other headers" do
    result = parse_headers(
      ["Content-Type: text/plain; charset=utf-8\r\n",
       "Subject: None\r\n",
       "Kind: of\r\n",
       "\r\n"])
    assert result == {:ok,
                      %{"CONTENT-TYPE" => {"text/plain", %{"charset" => "utf-8"}},
                        "SUBJECT" => "None",
                        "KIND" => "of"},
                      ""}
  end

  test "header value with delimited parameter" do
    result = parse_headers(
      ["Content-Type: attachment; boundary= \"hearsay\" ; unnecessary=\t\"unfortunately\"   \r\n",
       "\r\n"])
    assert result == {:ok,
                      %{"CONTENT-TYPE" =>
                        {"attachment",
                         %{"boundary" => "hearsay",
                           "unnecessary" => "unfortunately"}}},
                      ""}

    result = parse_headers(
      ["Content-Type: form-data; boundary=keep_this\"\r\n",
      "\r\n"])
    assert result == {:ok,
                      %{"CONTENT-TYPE" =>
                        {"form-data",
                         %{"boundary" => "keep_this\""}}},
                      ""}
  end

  test "unterminated header entry parameters" do
    {:need_more, _} = parse_headers("Content-Type: attachment; boundary")
    {:need_more, _} = parse_headers("Content-Type: attachment; boundary=nope;")
  end

  test "prematurely terminated header param" do
    assert parse_headers("Content-Type: attachment; boundary\r\n") == {:error, :header_param_name}
  end

  test "header name with whitespace" do
    assert parse_headers("OH YEAH: BROTHER\r\n\r\n") == {:error, :header_name}
  end

  test "unterminated headers" do
    {:need_more, {[], headers, "THIS-TRAIN"}} = parse_headers("this-train: is off the tracks\r\n")
    assert headers == %{"THIS-TRAIN" => "is off the tracks"}
  end

  test "newline terminated header name" do
    assert parse_headers("i-just-cant-seem-to-ever-shut-my-piehole\r\n") == {:error, :header_name}
  end

  test "unterminated header name" do
    {:need_more, _} = parse_headers("just-must-fuss")
  end

  test "unterminated header value" do
    {:need_more, _} = parse_headers("welcome: to the danger zone")
  end

  test "valid command with arguments" do
    command = parse_command("ADULT supervision is required\r\nsomething")
    assert command == {:ok, {"ADULT", ~w(supervision is required)}, "something"}
  end

  test "valid command without arguments" do
    command = parse_command("WUT\r\n")
    assert command == {:ok, {"WUT", []}, ""}
  end

  test "command name is upcased" do
    assert parse_command("AsDf\r\n") == {:ok, {"ASDF", []}, ""}
  end

  test "no command" do
    command = parse_command("\r\n")
    assert command == {:error, :command}
  end

  test "incomplete newline in command" do
    result = parse_command("HAL\nP MY NEW\rLINES\r\n")
    assert result == {:error, :command}
  end

  test "unterminated command" do
    {:need_more, good_state} = parse_command("MARKET FRESH HORSEMEAT\r")
    {:need_more, bad_state} = parse_command("MARKET FRESH HORSEMEAT")
    {command, [arg0], _} = good_state
    assert IO.iodata_to_binary(command) == "MARKET"
    assert IO.iodata_to_binary(arg0) == "FRESH"

    assert {:error, :command} == parse_command("\n", bad_state)
    assert {:ok, {"MARKET", ["FRESH", "HORSEMEAT"]}, "uh"} == parse_command("\nuh", good_state)
  end

  test "unterminated command without arguments" do
    {:need_more, {[], [], acc}} = parse_command("ants")
    assert IO.iodata_to_binary(acc) == "ants"
  end

end
