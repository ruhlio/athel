defmodule Athel.MultipartTest do
  use ExUnit.Case, async: true

  import Athel.Multipart

  @headers %{"MIME-VERSION" => "1.0",
             "CONTENT-TYPE" => %{value: "multipart/mixed", params: %{"BOUNDARY" => "lapalabra"}}}

  test "unsupported MIME version" do
    assert read_attachments(%{"MIME-VERSION" => "0.3"}, []) == {:error, :invalid_mime_version}
    assert read_attachments(%{}, []) == {:ok, nil}
  end

  test "content type header" do
    headers = %{"MIME-VERSION" => "1.0", "CONTENT-TYPE" => nil}

    assert read_attachments(%{headers | "CONTENT-TYPE" =>
                               %{value: "multipart/parallel", params: %{"BOUNDARY" => "word"}}}, []) == {:error, :unhandled_multipart_type}
    assert read_attachments(%{headers | "CONTENT-TYPE" => "multipart/mixed"}, []) == {:error, :invalid_multipart_type}

    assert read_attachments(headers, []) == {:ok, nil}
    assert read_attachments(%{headers | "CONTENT-TYPE" =>
                           %{value: "text/plain", params: %{"CHARSET" => "UTF8"}}}, []) == {:ok, nil}
    assert read_attachments(%{headers | "CONTENT-TYPE" => "text/plain"}, []) == {:ok, nil}
  end

  test "no attachments" do
    assert read_attachments(@headers,
      ["something",
       "or",
       "the",
       "other",
       "--lapalabra--"]) == {:ok, []}
  end

  test "one attachment" do
    attachment =
      %{type: "text/notplain",
        params: %{},
        filename: "cristo.txt",
        content: ["yo", "te", "llamo", "cristo", ""],
        attachments: []}

    assert read_attachments(@headers,
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
       "--lapalabra--"]) == {:ok, [attachment]}
  end

  test "two attachments" do
    attachments =
      [%{type: "text/notplain",
         params: %{},
         filename: "cristo.txt",
         content: ["yo", "te", "llamo", "cristo"],
         attachments: []},
       %{type: "text/html",
         params: %{},
         filename: "my_homepage.html",
         content: ["<h1>Cool things that I say to my friends</h1>", "Fire, walk with me"],
         attachments: []}]

    assert read_attachments(@headers,
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
       "--lapalabra--"]) == {:ok, attachments}
  end

  test "signed attachment" do
    {:ok, [post, signature]} = read_attachments(@headers, String.split(signed_attachment(), "\n"))

    # remove terminating \n
    {_, post_body} = signed_attachment_body() |> String.split("\n") |> List.pop_at(-1)
    {_, sig_body} = signed_attachment_signature() |> String.split("\n") |> List.pop_at(-1)

    assert post == %{type: "multipart/signed",
                     filename: nil,
                     params: %{
                       micalg: "pgp-sha1",
                       protocol: "application/pgp-signature",
                       signature: sig_body
                     },
                     content: post_body,
                     attachments: []}
    assert signature == %{type: "text/plain",
                          filename: nil,
                          params: %{},
                          content: ["_______________________________________________",
                                    "Gmane-discuss mailing list",
                                    "Gmane-discuss@hawk.netfonds.no",
                                    "http://hawk.netfonds.no/cgi-bin/mailman/listinfo/gmane-discuss",
                                    ""],
                         attachments: []}
  end

  test "signed attachment with no following attachments" do
    body = signed_attachment()
    |> String.split("--lapalabra\nContent-Type: text/plain; charset=\"us-ascii\"")
    |> List.first
    |> String.split("\n")

    {:ok, [post]} = read_attachments(@headers, body)
    assert post.type == "multipart/signed"
  end

  test "signed attachment with invalid signature" do
    body = signed_attachment()
    |> String.replace("-----BEGIN PGP SIGNATURE-----", "COMMENCE EMBEZZLING")
    |> String.split("\n")

    assert {:error, :invalid_signature} = read_attachments(@headers, body)
  end

  test "calls for help after the terminator are ignored" do
    {:ok, [attachment]} = read_attachments(@headers,
      ["--lapalabra",
       "Content-Type: text/plain",
       "",
       "siempre",
       "estas",
       "aquí",
       "--lapalabra--",
       "ayúdame"])
    assert attachment == %{
      type: "text/plain",
      params: %{},
      filename: nil,
      content: ["siempre", "estas", "aquí"],
      attachments: []
    }
  end

  test "base64 content" do
    {:ok, [attachment]} = read_attachments(@headers,
      ["--lapalabra",
       "Content-Transfer-Encoding: base64",
       "",
       "Q2FuJ3QgZ2V0IG15DQpsaW5lIGVuZGluZ3MKY29uc2lzdGVudA1pIHF1aXQ=",
       "--lapalabra--"])
    assert attachment.content == "Can't get my\r\nline endings\nconsistent\ri quit"
  end

  # this is real
  test "duplicate transfer encoding headers" do
    {:ok, [attachment]} = read_attachments(@headers,
      ["--lapalabra",
       "Content-Transfer-Encoding: base64",
       "Content-Transfer-Encoding: base64",
       "",
       "Q2FuJ3QgZ2V0IG15DQpsaW5lIGVuZGluZ3MKY29uc2lzdGVudA1pIHF1aXQ=",
       "--lapalabra--"])
    assert attachment.content == "Can't get my\r\nline endings\nconsistent\ri quit"
  end

  test "attachment without headers" do
    {:ok, [attachment]} = read_attachments(@headers,
      ["--lapalabra",
       "",
       "just a body",
       "kinda shoddy",
       "--lapalabra--"])
    assert attachment == %{
      type: "text/plain",
      params: %{},
      filename: nil,
      content: ["just a body", "kinda shoddy"],
      attachments: []
    }
  end

  test "missing terminator with no attachments" do
    assert read_attachments(@headers,
      ["just",
       "can't",
       "stop",
       "myself"]) == {:error, :unterminated_body}
  end

  test "missing terminator with an attachment" do
    assert read_attachments(@headers,
      ["la gloria",
       "de Dios",
       "--lapalabra",
       "Content-Type: text/plain",
       "",
       "get at me",
       "--lapalabra"]) == {:error, :unterminated_body}

    assert read_attachments(@headers,
      ["--lapalabra",
       "Content-Type: text/plain",
       "",
       "sacrebleu!"]) == {:error, :unterminated_body}
  end

  test "missing newline after headers" do
    assert read_attachments(@headers,
      ["--lapalabra",
       "Content-Type: bread/wine",
       "this is my body",
       "--lapalabra--"]) == {:error, :header_name}

    assert read_attachments(@headers,
      ["--lapalabra",
       "Content-Type: bread/wine"]) == {:error, :unterminated_headers}
  end

  test "unhandled encoding type" do
    assert read_attachments(@headers,
      ["--lapalabra",
       "Content-Transfer-Encoding: base58",
       "",
       "--lapalabra--"]) == {:error, :unhandled_transfer_encoding}
  end

  test "invalid encoding" do
    assert read_attachments(@headers,
      ["--lapalabra",
       "Content-Transfer-Encoding: base64",
       "",
       "can't b64",
       "two lines",
       "--lapalabra--"]) == {:error, :invalid_transfer_encoding}

    assert read_attachments(@headers,
      ["--lapalabra",
       "Content-Transfer-Encoding: base64",
       "",
       "whoopsy",
       "--lapalabra--"]) == {:error, :invalid_transfer_encoding}
  end

  test "unhandled content disposition" do
    assert read_attachments(@headers,
      ["--lapalabra",
       "Content-Disposition: inline; filename=\"nice_heels.jpg\"",
       "",
       "sometimes frosted",
       "sometimes sprinkled",
       "--lapalabra--"]) == {:error, :unhandled_content_disposition}
  end

  defp signed_attachment, do: """
--lapalabra
Content-Type: multipart/signed; boundary="=-=-=";
	micalg=pgp-sha1; protocol="application/pgp-signature"

--=-=-=
Content-Type: text/plain
Content-Transfer-Encoding: quoted-printable

Olly Betts <olly@survex.com> writes:

> Rainer M Krug <Rainer@krugs.de> writes:
>> 2) http://search.gmane.org/nov.php needs to support search in gwene
>> groups.
>
> Only gmane.* groups are indexed currently - if that changed, the search
> forms would probably just work.

That would be gret.

>
>> My question: could this be implemented in gmane?
>
> The main blocker for doing this would be that the search machine doesn't
> have a lot of spare disk space.

OK.

>
> A new machine is planned, but I'm not sure exactly when it'll actually
> happen.

If the indexing of gmane could be added after the new machine is
available, that would be great.

Could you please keep us posted?

Thanks,

Rainer

>
> Cheers,
>     Olly

=2D-=20
Rainer M. Krug
email: Rainer<at>krugs<dot>de
PGP: 0x0F52F982

--=-=-=
Content-Type: application/pgp-signature

-----BEGIN PGP SIGNATURE-----
Version: GnuPG/MacGPG2 v2.0.22 (Darwin)

iQEcBAEBAgAGBQJUQM65AAoJENvXNx4PUvmC3/8H/iV8GbKm6D8exL2Czxc+ADEF
XaPVO7pYKK2cBWLIZ+AmhEyiVBKa01/Ch6tkNjmR9snCtI0TH3R0srdjzuRu1yhx
CjMngcN2SSL1QXY4OYdYWfIY2/5RueIjm37/u3Y/qeJHoMJsE/nLb4jmvWLXdWAb
Ns6WUDuL5WFunDvm6qH6IBLPLTU8mLsKG2yhbdXUx+ObBnHQec0laNLIqwIt1eRa
Q0blwRK4TyqHf0XpdV8iB04b2EHYZUyuQsJc42In9fYesGHxmKwWkGEb3GA5C8X6
lKD62Xa8IEGAQu8dkgrXJrwcslyAIFHtX7ICtwqqvgQ2LFvHLEwUaPKDcsvqXqw=
=C/U1
-----END PGP SIGNATURE-----
--=-=-=--


--lapalabra
Content-Type: text/plain; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: inline

_______________________________________________
Gmane-discuss mailing list
Gmane-discuss@hawk.netfonds.no
http://hawk.netfonds.no/cgi-bin/mailman/listinfo/gmane-discuss

--lapalabra--
"""

  defp signed_attachment_body, do: """
Olly Betts <olly@survex.com> writes:

> Rainer M Krug <Rainer@krugs.de> writes:
>> 2) http://search.gmane.org/nov.php needs to support search in gwene
>> groups.
>
> Only gmane.* groups are indexed currently - if that changed, the search
> forms would probably just work.

That would be gret.

>
>> My question: could this be implemented in gmane?
>
> The main blocker for doing this would be that the search machine doesn't
> have a lot of spare disk space.

OK.

>
> A new machine is planned, but I'm not sure exactly when it'll actually
> happen.

If the indexing of gmane could be added after the new machine is
available, that would be great.

Could you please keep us posted?

Thanks,

Rainer

>
> Cheers,
>     Olly

=2D-=20
Rainer M. Krug
email: Rainer<at>krugs<dot>de
PGP: 0x0F52F982

"""

  defp signed_attachment_signature, do: """
Version: GnuPG/MacGPG2 v2.0.22 (Darwin)

iQEcBAEBAgAGBQJUQM65AAoJENvXNx4PUvmC3/8H/iV8GbKm6D8exL2Czxc+ADEF
XaPVO7pYKK2cBWLIZ+AmhEyiVBKa01/Ch6tkNjmR9snCtI0TH3R0srdjzuRu1yhx
CjMngcN2SSL1QXY4OYdYWfIY2/5RueIjm37/u3Y/qeJHoMJsE/nLb4jmvWLXdWAb
Ns6WUDuL5WFunDvm6qH6IBLPLTU8mLsKG2yhbdXUx+ObBnHQec0laNLIqwIt1eRa
Q0blwRK4TyqHf0XpdV8iB04b2EHYZUyuQsJc42In9fYesGHxmKwWkGEb3GA5C8X6
lKD62Xa8IEGAQu8dkgrXJrwcslyAIFHtX7ICtwqqvgQ2LFvHLEwUaPKDcsvqXqw=
=C/U1
"""

end
