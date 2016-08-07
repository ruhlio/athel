defmodule Athel.Nntp.ServerTest do
  use Athel.ModelCase

  alias Athel.{Group, Article}
  alias Athel.Nntp.Formattable

  setup do
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
    :gen_tcp.send(socket, "QUIT\r\n")
    {:ok, _} = :gen_tcp.recv(socket, 0)
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
    :gen_tcp.close(socket)
    #todo: assert CommunicationError was raised
  end

  test "too many arguments", %{socket: socket} do
    argument_counts = %{
      "CAPABILITIES" => 0,
      "QUIT" => 0,
      "LIST" => 2,
      "LISTGROUP" => 2,
      "GROUP" => 1
    }

    for {command, argument_count} <- argument_counts do
      arguments = Stream.repeatedly(fn -> "apple" end)
      |> Enum.take(argument_count + 1)
      |> Enum.join(" ")

      assert send_recv(socket, "#{command} #{arguments}\r\n") == "501 Too many arguments\r\n"
    end

    quit(socket)
  end

  test "CAPABILITIES", %{socket: socket} do
    assert send_recv(socket, "CAPABILITIES\r\n") == "101 Listing capabilities\r\nVERSION 2\r\nPOST\r\nLIST ACTIVE NEWGROUPS\r\n.\r\n"

    quit(socket)
  end

  test "LIST", %{socket: socket} do
    Repo.insert!(%Group
      {
        name: "aardvarks.are.delicious",
        description: "Aardvark enthusiasts welcome",
        status: "y",
        low_watermark: 1,
        high_watermark: 3
      })
    Repo.insert!(%Group
      {
        name: "cartoons.chinese",
        description: "Glorious Chinese animation",
        status: "m",
        low_watermark: 5,
        high_watermark: 10
      })

    list = send_recv(socket, "LIST\r\n")
    list_active = send_recv(socket, "LIST ACTIVE\r\n")
    assert list == list_active
    assert list == "215 Listing groups\r\naardvarks.are.delicious 3 1 y\r\ncartoons.chinese 10 5 m\r\n.\r\n"
    assert send_recv(socket, "LIST NEWSGROUPS\r\n")== "215 Listing group descriptions\r\naardvarks.are.delicious Aardvark enthusiasts welcome\r\ncartoons.chinese Glorious Chinese animation\r\n.\r\n"
    assert send_recv(socket, "LIST ACTIVE *.drugs\r\n") == "501 Invalid LIST arguments\r\n"

    quit(socket)
  end

  test "LISTGROUP", %{socket: socket} do
    group = setup_models(10)
    Repo.update Group.changeset(group, %{low_watermark: 5, high_watermark: 10})

    assert send_recv(socket, "LISTGROUP\r\n") == "412 Select a group first, ya dingus\r\n"
    assert send_recv(socket, "LISTGROUP DINGUS.LAND\r\n") =~ status(411)

    valid_response = "211 5 5 10 fun.times\r\n5\r\n6\r\n7\r\n8\r\n9\r\n.\r\n"
    assert send_recv(socket, "LISTGROUP fun.times\r\n") == valid_response
    assert send_recv(socket, "LISTGROUP\r\n") == valid_response
    assert send_recv(socket, "LISTGROUP fun.times 5-\r\n") == valid_response

    assert send_recv(socket, "LISTGROUP fun.times 5-7\r\n") == "211 5 5 10 fun.times\r\n5\r\n6\r\n.\r\n"

    assert send_recv(socket, "LISTGROUP fun.times 7-5\r\n") == "211 5 5 10 fun.times\r\n.\r\n"

    quit(socket)
  end

  test "GROUP", %{socket: socket} do
    group = setup_models(2)
    Repo.update Group.changeset(group, %{low_watermark: 5, high_watermark: 10})

    assert send_recv(socket, "GROUP\r\n") == "501 Syntax error: group name must be provided\r\n"
    assert send_recv(socket, "GROUP asinine.debate\r\n") =~ status(411)
    assert send_recv(socket, "GROUP fun.times\r\n") == "211 5 5 10 fun.times\r\n"
    # verify selected group was set for session
    assert send_recv(socket, "LISTGROUP\r\n") =~ status(211)

    quit(socket)
  end

  test "ARTICLE", %{socket: socket} do
    setup_models(5)
    article = Article
    |> Repo.get("01@test.com")
    |> Repo.preload(:groups)
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

  defp send_recv(socket, payload) do
    :gen_tcp.send(socket, payload)
    {:ok, resp} = :gen_tcp.recv(socket, 0)
    resp
  end

  # handle single or multiline
  defp status(code), do: Regex.compile!("^#{code}(.|\r|\n)*\r\n$", "m")

end
