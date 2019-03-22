defmodule Athel.Nntp.ServerTest do
  use Athel.ModelCase

  alias Timex.Parse.DateTime.Tokenizers.Strftime
  alias Athel.{Group, Article, AuthService, NntpService}
  alias Athel.Nntp.Formattable

  setup do
    {:ok, _} = AuthService.create_user("bigboy@pig.farm", "password")

    socket = connect()
    {:ok, _welcome} = :gen_tcp.recv(socket, 0)

    {:ok, socket: socket}
  end

  defp connect do
    {:ok, socket} = :gen_tcp.connect({127, 0, 0, 1}, 8119,
      [:binary, active: false, packet: :raw])
    socket
  end

  # setup's on_exit callback runs after the context (therefore the socket)
  # has already been cleaned up, so quit must be called manually
  defp quit(socket) do
    send_recv(socket, "QUIT\r\n")
  end

  test "hello/goodbye", %{socket: setup_socket} do
    socket = connect()

    {:ok, welcome} = :gen_tcp.recv(socket, 0)
    assert welcome =~ status(200)

    assert send_recv(socket, "QUIT\r\n") =~ status(205)

    :gen_tcp.close(socket)
    quit(setup_socket)
  end

  test "closing connection without receiving QUIT", %{socket: socket} do
    #TODO: assert CommunicationError was raised
    :gen_tcp.close(socket)
  end

  test "sending too much data", %{socket: socket} do
    #TODO: assert CommunicationError was raised/eat error output
    too_much_data = Stream.repeatedly(fn -> "a" end)
    |> Enum.take(300_000)
    :gen_tcp.send(socket, too_much_data)
    assert :gen_tcp.recv(socket, 0) == {:error, :closed}
  end

  test "too many arguments", %{socket: socket} do
    argument_counts = %{
      "CAPABILITIES" => 0,
      "QUIT" => 0,
      "LIST" => 2,
      "LISTGROUP" => 2,
      "GROUP" => 1,
      "STARTTLS" => 0,
      "AUTHINFO" => 2,
      "POST" => 0,
      "IHAVE" => 1,
      "NEWGROUPS" => 2,
      "NEWNEWS" => 3,
      "CHECK" => 1,
      "TAKETHIS" => 1
    }

    for {command, argument_count} <- argument_counts do
      arguments = Stream.repeatedly(fn -> "apple" end)
      |> Enum.take(argument_count + 1)
      |> Enum.join(" ")

      assert send_recv(socket, "#{command} #{arguments}\r\n") == "501 Too many arguments\r\n"
    end

    quit(socket)
  end

  test "no such command", %{socket: socket} do
    assert send_recv(socket, "SAY MY NAMe\r\n") =~ status(501)
    quit(socket)
  end

  test "CAPABILITIES", %{socket: socket} do
    assert send_recv(socket, "CAPABILITIES\r\n") == "101 Listing capabilities\r\nVERSION 2\r\nREADER\r\nPOST\r\nLIST ACTIVE NEWGROUPS\r\nSTARTTLS\r\nIHAVE\r\nSTREAMING\r\nAUTHINFO USER\r\n.\r\n"

    quit(socket)
  end

  test "LIST", %{socket: socket} do
    Repo.insert! %Group {
      name: "aardvarks.are.delicious",
      description: "Aardvark enthusiasts welcome",
      status: "y",
      low_watermark: 1,
      high_watermark: 3
    }
    Repo.insert! %Group {
      name: "cartoons.chinese",
      description: "Glorious Chinese animation",
      status: "m",
      low_watermark: 5,
      high_watermark: 10
    }

    list = send_recv(socket, "LIST\r\n")
    list_active = send_recv(socket, "LIST ACTIVE\r\n")
    assert list == list_active
    assert list == "215 Listing groups\r\naardvarks.are.delicious 3 1 y\r\ncartoons.chinese 10 5 m\r\n.\r\n"
    assert send_recv(socket, "LIST NEWSGROUPS\r\n") == "215 Listing group descriptions\r\naardvarks.are.delicious Aardvark enthusiasts welcome\r\ncartoons.chinese Glorious Chinese animation\r\n.\r\n"
    assert send_recv(socket, "LIST ACTIVE *.drugs\r\n") == "501 Invalid LIST arguments\r\n"

    quit(socket)
  end

  test "GROUP", %{socket: socket} do
    group = setup_models(2)
    Repo.update Group.changeset(group, %{low_watermark: 5, high_watermark: 10})

    assert send_recv(socket, "GROUP\r\n") =~ status(501)
    assert send_recv(socket, "GROUP asinine.debate\r\n") =~ status(411)
    assert send_recv(socket, "GROUP fun.times\r\n") == "211 5 5 10 fun.times\r\n"
    # verify selected group was set for session
    assert send_recv(socket, "LISTGROUP\r\n") =~ status(211)

    quit(socket)
  end

  test "LISTGROUP", %{socket: socket} do
    group = setup_models(10)
    Repo.update Group.changeset(group, %{high_watermark: 10})

    assert send_recv(socket, "LISTGROUP\r\n") =~ status(412)
    assert send_recv(socket, "LISTGROUP DINGUS.LAND\r\n") =~ status(411)

    valid_response = "211 10 0 10 fun.times\r\n1\r\n2\r\n3\r\n4\r\n5\r\n6\r\n7\r\n8\r\n9\r\n.\r\n"
    assert send_recv(socket, "LISTGROUP fun.times\r\n") == valid_response
    assert send_recv(socket, "LISTGROUP\r\n") == valid_response
    assert send_recv(socket, "LISTGROUP fun.times 5-\r\n") == "211 10 0 10 fun.times\r\n5\r\n6\r\n7\r\n8\r\n9\r\n.\r\n"

    assert send_recv(socket, "LISTGROUP fun.times 5-7\r\n") == "211 10 0 10 fun.times\r\n5\r\n6\r\n.\r\n"

    assert send_recv(socket, "LISTGROUP fun.times 7-5\r\n") == "211 10 0 10 fun.times\r\n.\r\n"

    quit(socket)
  end

  test "XOVER", %{socket: socket} do
    _group = setup_models(2)

    assert send_recv(socket, "XOVER\r\n") =~ status(420)
    assert send_recv(socket, "XOVER 1-\r\n") =~ status(412)

    send_recv(socket, "GROUP fun.times\r\n")
    assert send_recv(socket, "XOVER 0\r\n") =~ ~r/224 XOVER OVER\r\n0\tTalking to myself\tMe\t\d{14}\t00@test.com\t\t34\t1/
    multi_response = ~r/224 XOVER OVER\r\n0\tTalking to myself\tMe\t\d{14}\t00@test.com\t\t34\t1\r\n1\tTalking to myself\tMe\t\d{14}\t01@test.com\t\t34\t1/
    assert send_recv(socket, "XOVER 0-\r\n") =~ multi_response
    assert send_recv(socket, "XOVER 0-2\r\n") =~ multi_response

    send_recv(socket, "QUIT\r\n")
  end

  test "LAST", %{socket: socket} do
    setup_models(3)

    assert send_recv(socket, "LAST\r\n") =~ status(412)
    assert send_recv(socket, "GROUP fun.times\r\n") =~ status(211)
    assert send_recv(socket, "LAST\r\n") =~ status(420)
    assert send_recv(socket, "ARTICLE 0\r\n") =~ status(220)
    assert send_recv(socket, "LAST\r\n") =~ status(422)
    assert send_recv(socket, "ARTICLE 2\r\n") =~ status(220)
    assert send_recv(socket, "LAST\r\n") == "223 1 <01@test.com>\r\n"

    quit(socket)
  end

  test "NEXT", %{socket: socket} do
    setup_models(3)

    assert send_recv(socket, "NEXT\r\n") =~ status(412)
    assert send_recv(socket, "GROUP fun.times\r\n") =~ status(211)
    assert send_recv(socket, "NEXT\r\n") =~ status(420)
    assert send_recv(socket, "ARTICLE 2\r\n") =~ status(220)
    assert send_recv(socket, "NEXT\r\n") =~ status(421)
    assert send_recv(socket, "ARTICLE 1\r\n") =~ status(220)
    assert send_recv(socket, "NEXT\r\n") == "223 2 <02@test.com>\r\n"

    quit(socket)
  end

  test "ARTICLE", %{socket: socket} do
    setup_models(5)
    article = Article
    |> Repo.get("01@test.com")
    |> Repo.preload(:groups)
    |> Repo.preload(:attachments)
    |> Formattable.format

    assert send_recv(socket, "ARTICLE <nananananana@batman>\r\n") =~ status(430)
    assert send_recv(socket, "ARTICLE <01@test.com>\r\n") == "220 0 <01@test.com>\r\n#{article}"
    assert send_recv(socket, "ARTICLE\r\n") =~ status(420)
    assert send_recv(socket, "ARTICLE 2\r\n") =~ status(412)
    send_recv(socket, "GROUP fun.times\r\n")
    assert send_recv(socket, "ARTICLE\r\n") =~ status(420)
    assert send_recv(socket, "ARTICLE 1\r\n") == "220 1 <01@test.com>\r\n#{article}"
    assert send_recv(socket, "ARTICLE\r\n") == "220 1 <01@test.com>\r\n#{article}"
    assert send_recv(socket, "ARTICLE 50\r\n") =~ status(423)

    quit(socket)
  end

  test "HEAD", %{socket: socket} do
    setup_models(2)
    {headers, _} = Article
    |> Repo.get("01@test.com")
    |> Repo.preload(:groups)
    |> Repo.preload(:attachments)
    |> Article.get_headers
    headers = headers |> Formattable.format

    assert send_recv(socket, "HEAD <01@test.com>\r\n") == "220 0 <01@test.com>\r\n#{headers}"

    quit(socket)
  end

  test "BODY", %{socket: socket} do
    setup_models(2)

    assert send_recv(socket, "BODY <01@test.com>\r\n") == "220 0 <01@test.com>\r\nLET'S ROCK OUT FOR JESUS & AMERICA\r\n.\r\n"
    quit(socket)
  end

  test "STAT", %{socket: socket} do
    setup_models(2)
    assert send_recv(socket, "STAT <01@test.com>\r\n") == "223 0 <01@test.com>\r\n"

    quit(socket)
  end

  test "POST", %{socket: socket} do
    group = setup_models(3)
    other_group = Repo.insert! %Group {
      name: "cartoons.chinese",
      description: "Glorious Chinese animation",
      status: "m",
      low_watermark: 5,
      high_watermark: 10
    }
    new_article = %Article {
      subject: "MY WAR",
      from: ~s("MARDAR" <mardar@wardar.karfar>),
      groups: [group, other_group],
      attachments: [],
      content_type: "text/plain",
      headers: %{},
      body: "YOU'RE ONE OF THEM"
    }

    assert send_recv(socket, "POST\r\n") =~ status(440)
    login(socket)
    assert send_recv(socket, "POST\r\n") =~ status(340)
    assert send_recv(socket, Formattable.format(new_article)) =~ status(240)

    {_, created_article} = NntpService.get_article_by_index(group.name, 3)
    assert created_article.subject == new_article.subject
    assert created_article.body == new_article.body

    Repo.update! change(group, status: "n")
    send_recv(socket, "POST\r\n")
    assert send_recv(socket, Formattable.format(new_article)) =~ status(441)

    quit(socket)
  end

  test "MODE READER", %{socket: socket} do
    assert send_recv(socket, "MODE READER\r\n") =~ status(200)
    quit(socket)
  end

  test "STARTTLS", %{socket: socket} do
    assert send_recv(socket, "STARTTLS\r\n") =~ status(382)
    socket = upgrade_to_ssl(socket)

    assert send_recv(socket, "CAPABILITIES\r\n") =~ status(101)
    assert send_recv(socket, "STARTTLS\r\n") =~ status(502)

    quit(socket)

    socket = connect()
    {:ok, _welcome} = :gen_tcp.recv(socket, 0)
    login(socket)
    assert send_recv(socket, "STARTTLS\r\n") =~ status(502)
    quit(socket)
  end

  test "AUTHINFO", %{socket: socket} do
    #assert send_recv(socket, "AUTHINFO USER jimbo\r\n") =~ status(483)
    assert send_recv(socket, "STARTTLS\r\n") =~ status(382)
    socket = upgrade_to_ssl(socket)

    assert send_recv(socket, "AUTHINFO PASS password\r\n") =~ status(482)
    assert send_recv(socket, "AUTHINFO USER terry\r\n") =~ status(381)
    assert send_recv(socket, "AUTHINFO PASS password\r\n") =~ status(481)

    assert send_recv(socket, "AUTHINFO USER jimbo\r\n") =~ status(381)
    assert send_recv(socket, "AUTHINFO PASS hwat\r\n") =~ status(481)
    assert send_recv(socket, "AUTHINFO PASS hwat\r\n") =~ status(482)

    login(socket)
    refute send_recv(socket, "CAPABILITIES\r\n") =~ "AUTHINFO"
    assert send_recv(socket, "AUTHINFO PASS dude\r\n") =~ status(502)
    assert send_recv(socket, "AUTHINFO USER jimbo\r\n") =~ status(502)

    quit(socket)
  end

  test "IHAVE", %{socket: socket} do
    group = setup_models(3)
    article = %Article {
      message_id: "03@test.com",
      groups: [group],
      from: "You",
      subject: "Is this me?",
      date: Timex.to_datetime({{2012, 7, 4}, {4, 51, 23}}, "Etc/UTC"),
      headers: %{},
      parent_message_id: nil,
      attachments: [],
      content_type: "text/plain",
      body: "I cannot fathom why"
    }

    assert send_recv(socket, "IHAVE <123@abc.cdf>\r\n") =~ status(483)
    login(socket)

    assert send_recv(socket, "IHAVE <02@test.com>\r\n") =~ status(435)
    assert send_recv(socket, "IHAVE <03@test.com>\r\n") =~ status(335)
    assert send_recv(socket, Formattable.format(article)) =~ status(235)
    assert send_recv(socket, "ARTICLE <03@test.com>\r\n") == "220 0 <03@test.com>\r\n#{Formattable.format(article)}"
    #TODO: reject articles (437) based off of group
    #TODO: causes internal blowup and return 436

    quit(socket)
  end

  test "DATE", %{socket: socket} do
    date =
      with [_, raw_date] <- Regex.run(~r/^111 (\d{14})\r\n$/, send_recv(socket, "DATE\r\n")),
           {:ok, date} <- Timex.parse(raw_date, "%Y%m%d%H%M%S", Strftime),
      do: date
    assert 0 == Timex.compare(Timex.now(), date, :minutes)

    quit(socket)
  end

  test "NEWGROUPS", %{socket: socket} do
    setup_models()
    assert send_recv(socket, "NEWGROUPS newspaper 1122\r\n") =~ status(501)
    assert send_recv(socket, "NEWGROUPS 20120408 hihi\r\n") =~ status(501)
    assert send_recv(socket, "NEWGROUPS 99999999 9999\r\n") =~ status(501)

    before = Timex.now() |> Timex.subtract(Timex.Duration.from_minutes(1))
    date = Timex.format!(before, "%Y%m%d", :strftime)
    time = Timex.format!(before, "%H%M", :strftime)
    assert send_recv(socket, "NEWGROUPS #{date} #{time}\r\n") == "231 HERE WE GO\r\nfun.times 0 0 y\r\n.\r\n"

    quit(socket)
  end

  test "NEWNEWS", %{socket: socket} do
    setup_models(2)
    assert send_recv(socket, "NEWNEWS sherry cheesy puffs\r\n") =~ status(501)

    before = Timex.now() |> Timex.subtract(Timex.Duration.from_minutes(1))
    date = Timex.format!(before, "%Y%m%d", :strftime)
    time = Timex.format!(before, "%H%M", :strftime)
    assert send_recv(socket, "NEWNEWS fun.times #{date} #{time}\r\n") == "230 HOO-WEE\r\n<00@test.com>\r\n<01@test.com>\r\n.\r\n"
    assert send_recv(socket, "NEWNEWS butts #{date} #{time}\r\n") == "230 HOO-WEE\r\n.\r\n"

    quit(socket)
  end

  test "article streaming", %{socket: socket} do
    setup_models(1)
    article = Article
    |> Repo.get!("00@test.com")
    |> Repo.preload(:groups)
    |> Repo.preload(:attachments)

    assert send_recv(socket, "MODE STREAM\r\n") =~ status(203)

    assert send_recv(socket, "CHECK asd\r\n") =~ status(501)
    assert send_recv(socket, "CHECK <00@test.com>\r\n") =~ "438 <00@test.com>\r\n"
    assert send_recv(socket, "CHECK <01@test.com>\r\n") =~ "238 <01@test.com>\r\n"

    assert send_recv(socket, "TAKETHIS <whoopsy@test.com\r\n#{Formattable.format(article)}") =~ status(501)
    assert send_recv(socket, "TAKETHIS <00@test.com>\r\n#{Formattable.format(article)}") == "439 <00@test.com>\r\n"
    new_article = %{article | message_id: "01@test.com"}
    assert send_recv(socket, "TAKETHIS <01@test.com>\r\n#{Formattable.format(new_article)}") =~ "239 <01@test.com>\r\n"

    quit(socket)
  end

  defp send_recv(socket = {:sslsocket, _, _}, payload) do
    :ssl.send(socket, payload)
    {:ok, resp} = :ssl.recv(socket, 0)
    resp
  end

  defp send_recv(socket, payload) do
    :gen_tcp.send(socket, payload)
    {:ok, resp} = :gen_tcp.recv(socket, 0)
    resp
  end

  defp upgrade_to_ssl(socket, cacertfile \\ nil) do
    opts = if is_nil(cacertfile), do: [], else: [cacertfile: cacertfile]
    {:ok, socket} = :ssl.connect(socket, opts)
    socket
  end

  defp login(socket) do
    assert send_recv(socket, "AUTHINFO USER bigboy@pig.farm\r\n") =~ status(381)
    assert send_recv(socket, "AUTHINFO PASS password\r\n") =~ status(281)
  end

  # handle single or multiline
  defp status(code), do: Regex.compile!("^#{code}(.|\r|\n)*\r\n$", "m")

end
