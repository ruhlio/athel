defmodule Athel.Nntp.ParserTest do
  use ExUnit.Case, async: true

  import Athel.Nntp.Parser

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

  test "strange multiline" do
    first = [[], "17428\tRe: Firefox support mailing list\tAnton Shepelev <anton.txt@gmail.com>\tSun, 29 Apr 2018 14:12:56 +0300\t<20180429141256.c921da46c2de9d8c4e5e102e@gmail.com>\t<20180429131604.4a1a24cda43904f0db317a00@gmail.com> <87o9i29uf7.fsf@ist.utl.pt>\t3214\t12\tXref: news.gmane.org gmane.discuss:17428\r\n17429\tRe: Firefox support mailing list\tasjo@koldfront.dk (Adam =?utf-8?Q?Sj=C3=B8gren?=)\tSun, 29 Apr 2018 14:04:34 +0200\t<87d0yicj71.fsf@tullinup.koldfront.dk>\t<20180429131604.4a1a24cda43904f0db317a00@gmail.com>\t4172\t12\tXref: news.gmane.org gmane.discuss:17429\r\n17430\tRe: Firefox support mailing list\tAnton Shepelev <anton.txt@gmail.com>\tSun, 29 Apr 2018 18:01:59 +0300\t<20180429180159.34c24d013a2dcae9935f6a6d@gmail.com>\t<20180429131604.4a1a24cda43904f0db317a00@gmail.com> <87d0yicj71.fsf@tullinup.koldfront.dk>\t3260\t13\tXref: news.gmane.org gmane.discuss:17430\r\n17431\tRe: Firefox support mailing list\tGood Guy <xfsgpr@hotmail.com>\tSun, 29 Apr 2018 17:38:10 +0100\t<pc4s9f$hi2$1@blaine.gmane.org>\t<20180429131604.4a1a24cda43904f0db317a00@gmail.com> <87d0yicj71.fsf@tullinup.koldfront.dk>\t3773\t11\tXref: news.gmane.org gmane.discuss:17431\r\n17432\tRe: Firefox support mailing list\t=?utf-8?Q?Adam_Sj=C3=B8gren?= <asjo@koldfront.dk>\tSun, 29 Apr 2018 19:27:20 +0200\t<87o9i1ncsn.fsf@tullinup.koldfront.dk>\t<20180429131604.4a1a24cda43904f0db317a00@gmail.com> <87d0yicj71.fsf@tullinup.koldfront.dk> <pc4s9f$hi2$1@blaine.gmane.org>\t4382\t13\tXref: new"]
    second = [[], "scuss:17432\r\n.\r\n"]

    {:need_more, state} = parse_multiline(first)
    {:ok, _, ""} = parse_multiline(second)
  end

  test "valid headers" do
    headers = parse_headers(["Content-Type: funky/nasty\r\nBoogie-Nights: You missed that boat\r\n", "\r\n"])
    assert headers == {:ok,
                       %{"CONTENT-TYPE" => "funky/nasty",
                         "BOOGIE-NIGHTS" => "You missed that boat"},
                       ""}
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
    {:need_more, {[], headers}} = parse_headers("this-train: is off the tracks\r\n")
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
