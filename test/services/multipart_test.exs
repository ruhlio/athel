defmodule Athel.MultipartTest do
  use ExUnit.Case, async: true

  import Athel.Multipart

  test "unsupported MIME version" do
    assert get_boundary(%{"MIME-VERSION" => "0.3"}) == {:error, :invalid_mime_version}
    assert get_boundary(%{}) == {:error, :invalid_mime_version}
  end

  test "content type header" do
    error = {:error, :unhandled_multipart_type}
    headers = %{"MIME-VERSION" => "1.0", "CONTENT-TYPE" => nil}

    assert get_boundary(headers) == error
    assert get_boundary(%{headers | "CONTENT-TYPE" => "text/plain"}) == error
    assert get_boundary(%{headers | "CONTENT-TYPE" =>
                           {"multipart/parallel", %{"boundary" => "word"}}}) == error

    assert get_boundary(%{headers | "CONTENT-TYPE" =>
                         {"multipart/mixed", %{"boundary" => "persnickety"}}}) == {:ok, "persnickety"}
  end

  test "no attachments" do
    
  end

  test "one attachment" do
  end

  test "two attachments" do
    
  end

  test "no filename" do
    
  end

  test "no content" do
    
  end

  test "base64 content" do
    
  end

  test "missing terminator with no attachments" do
    
  end

  test "missing terminator with an attachment" do
    
  end

  test "missing newline after headers" do
    
  end

  test "invalid encoding type" do
    
  end

  test "invalid encoding" do
    
  end

end
