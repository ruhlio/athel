defmodule Athel.MultipartTest do
  use ExUnit.Case, async: true

  import Athel.Multipart

  test "unsupported MIME version" do
    assert get_boundary(%{"MIME-VERSION" => "0.3"}) == {:error, :invalid_mime_version}
    assert get_boundary(%{}) == {:ok, nil}
  end

  test "content type header" do
    error = {:error, :unhandled_multipart_type}
    headers = %{"MIME-VERSION" => "1.0", "CONTENT-TYPE" => nil}

    assert get_boundary(%{headers | "CONTENT-TYPE" =>
                           {"multipart/parallel", %{"boundary" => "word"}}}) == error
    assert get_boundary(%{headers | "CONTENT-TYPE" => "multipart/mixed"}) == {:error, :invalid_multipart_type}

    assert get_boundary(%{headers | "CONTENT-TYPE" =>
                           {"multipart/mixed", %{"boundary" => "persnickety"}}}) == {:ok, "persnickety"}
    assert get_boundary(headers) == {:ok, nil}
    assert get_boundary(%{headers | "CONTENT-TYPE" =>
                           {"text/plain", %{"charset" => "utf8"}}}) == {:ok, nil}
    assert get_boundary(%{headers | "CONTENT-TYPE" => "text/plain"}) == {:ok, nil}
  end

  test "no attachments" do
    assert read_attachments(
      ["something",
       "or",
       "the",
       "other",
       "--trabajar--"],
      "trabajar") == {:ok, []}
  end

  test "one attachment" do
    attachment =
      %{type: "text/notplain",
        filename: "cristo.txt",
        content: ["yo", "te", "llamo", "cristo", ""]}

    assert read_attachments(
      ["IGNORE",
       "ME",
       "--lapalabra",
       "Content-Type: text/notplain",
       "Content-Disposition: attachment ; filename=\"cristo.txt\"",
       "",
       "yo",
       "te",
       "llamo",
       "cristo",
       "",
       "--lapalabra--"],
      "lapalabra") == {:ok, [attachment]}
  end

  test "two attachments" do
    attachments =
      [%{type: "text/notplain",
         filename: "cristo.txt",
         content: ["yo", "te", "llamo", "cristo"]},
       %{type: "text/html",
         filename: "my_homepage.html",
         content: ["<h1>Cool things that I say to my friends</h1>", "Fire, walk with me"]}]

    assert read_attachments(
      ["IGNORE",
       "ME",
       "--lapalabra",
       "Content-Type: text/notplain",
       "Content-Disposition: attachment ; filename=\"cristo.txt\"",
       "",
       "yo",
       "te",
       "llamo",
       "cristo",
       "--lapalabra",
       "Content-Type: text/html",
       "Content-Disposition: attachment; filename=\"my_homepage.html\"",
       "",
       "<h1>Cool things that I say to my friends</h1>",
       "Fire, walk with me",
       "--lapalabra--"],
      "lapalabra") == {:ok, attachments}
  end

  test "calls for help after the terminator are ignored" do
    {:ok, [attachment]} = read_attachments(
      ["--LUCHADOR",
       "Content-Type: text/plain",
       "",
       "siempre",
       "estas",
       "aquí",
       "--LUCHADOR--",
       "ayúdame"],
      "LUCHADOR")
    assert attachment == %{type: "text/plain", filename: nil, content: ["siempre", "estas", "aquí"]}
  end

  test "base64 content" do
    {:ok, [attachment]} = read_attachments(
      ["--planter",
       "Content-Transfer-Encoding: base64",
       "",
       "Q2FuJ3QgZ2V0IG15DQpsaW5lIGVuZGluZ3MKY29uc2lzdGVudA1pIHF1aXQ=",
       "--planter--"],
      "planter")
    assert attachment.content == ["Can't get my", "line endings", "consistent", "i quit"]
  end

  test "attachment without headers" do
    {:ok, [attachment]} = read_attachments(
      ["--box",
       "just a body",
       "kinda shoddy",
       "--box--"],
      "box")
    assert attachment == %{type: "text/plain", filename: nil, content: ["just a body", "kinda shoddy"]}
  end

  test "missing terminator with no attachments" do
    assert read_attachments(
      ["just",
       "can't",
       "stop",
       "myself"],
      "FASTLANE") == {:error, :unterminated_body}
  end

  test "missing terminator with an attachment" do
    assert read_attachments(
      ["la gloria",
       "de Dios",
       "--amigo",
       "Content-Type: text/plain",
       "",
       "get at me",
       "--amigo"],
      "amigo") == {:error, :unterminated_body}

    assert read_attachments(
      ["--amigo",
       "Content-Type: text/plain",
       "",
       "sacrebleu!"],
      "amigo") == {:error, :unterminated_body}
  end

  test "missing newline after headers" do
    assert read_attachments(
      ["--lastsupper",
       "Content-Type: bread/wine",
       "this is my body",
       "--lastsupper--"],
      "lastsupper") == {:error, :invalid_header}

    assert read_attachments(
      ["--lastsupper",
       "Content-Type: bread/wine"],
      "lastsupper") == {:error, :unterminated_headers}
  end

  test "unhandled encoding type" do
    assert read_attachments(
      ["--toots",
       "Content-Transfer-Encoding: base58",
       "",
       "--toots--"],
      "toots") == {:error, :unhandled_encoding}
  end

  test "invalid encoding" do
    assert read_attachments(
      ["--boots",
       "Content-Transfer-Encoding: base64",
       "",
       "can't b64",
       "two lines",
       "--boots--"],
      "boots") == {:error, :invalid_encoding}

    assert read_attachments(
      ["--boots",
       "Content-Transfer-Encoding: base64",
       "",
       "whoopsy",
       "--boots--"],
      "boots") == {:error, :invalid_encoding}
  end

  test "unhandled content disposition" do
    assert read_attachments(
      ["--butts",
       "Content-Disposition: inline; filename=\"nice_heels.jpg\"",
       "",
       "sometimes frosted",
       "sometimes sprinkled",
       "--butts--"],
      "butts") == {:error, :unhandled_content_disposition}

    assert read_attachments(
      ["--butts",
       "Content-Disposition: inline",
       "",
       "sometimes frosted",
       "sometimes sprinkled",
       "--butts--"],
      "butts") == {:error, :unhandled_content_disposition}
  end

end
