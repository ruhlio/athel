defmodule Athel.Nntp.ServerTest do
  use Athel.ModelCase

  alias Athel.Group

  setup do
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
    assert welcome == "200 WELCOME FRIEND\r\n"

    :gen_tcp.send(socket, "QUIT\r\n")
    {:ok, goodbye} = :gen_tcp.recv(socket, 0)
    assert goodbye == "205 SEE YA\r\n"

    :gen_tcp.close(socket)
    quit(setup_socket)
  end

  test "closing connection without receiving QUIT", %{socket: socket} do
    :gen_tcp.close(socket)
    #todo: assert CommunicationError was raised
  end

  test "CAPABILITIES", %{socket: socket} do
    :gen_tcp.send(socket, "CAPABILITIES\r\n")
    {:ok, capabilities} = :gen_tcp.recv(socket, 0)
    assert capabilities == "101 Listing capabilities\r\nVERSION 2\r\nPOST\r\nLIST ACTIVE NEWGROUPS\r\n.\r\n"

    quit(socket)
  end

  test "LIST", %{socket: socket} do
    :gen_tcp.send(socket, "LIST\r\n")
    {:ok, list} = :gen_tcp.recv(socket, 0)
    :gen_tcp.send(socket, "LIST ACTIVE\r\n")
    {:ok, list_active} = :gen_tcp.recv(socket, 0)
    assert list == list_active
    assert list == "215 Listing groups\r\naardvarks.are.delicious 3 1 y\r\ncartoons.chinese 10 5 m\r\n.\r\n"

    :gen_tcp.send(socket, "LIST NEWSGROUPS\r\n")
    {:ok, newsgroups} = :gen_tcp.recv(socket, 0)
    assert newsgroups == "215 Listing group descriptions\r\naardvarks.are.delicious Aardvark enthusiasts welcome\r\ncartoons.chinese Glorious Chinese animation\r\n.\r\n"

    :gen_tcp.send(socket, "LIST ACTIVE *.drugs\r\n")
    {:ok, invalid} = :gen_tcp.recv(socket, 0)
    assert invalid == "501 Invalid LIST arguments\r\n"

    quit(socket)
  end

  test "LISTGROUP", %{socket: socket} do
    group = setup_models(10)
    Repo.update Group.changeset(group, %{low_watermark: 5, high_watermark: 10})

    :gen_tcp.send(socket, "LISTGROUP\r\n")
    {:ok, no_group_selected} = :gen_tcp.recv(socket, 0)
    assert no_group_selected == "412 Select a group first, ya dingus\r\n"

    :gen_tcp.send(socket, "LISTGROUP DINGUS.LAND\r\n")
    {:ok, no_such_group} = :gen_tcp.recv(socket, 0)
    assert no_such_group == "411 No such group\r\n"

    valid_response = "211 5 5 10 fun.times\r\n5\r\n6\r\n7\r\n8\r\n9\r\n.\r\n"

    :gen_tcp.send(socket, "LISTGROUP fun.times\r\n")
    {:ok, list} = :gen_tcp.recv(socket, 0)
    assert list == valid_response

    :gen_tcp.send(socket, "LISTGROUP\r\n")
    {:ok, selected_group_list} = :gen_tcp.recv(socket, 0)
    assert selected_group_list == valid_response

    :gen_tcp.send(socket, "LISTGROUP fun.times 5-\r\n")
    {:ok, open_range_list} = :gen_tcp.recv(socket, 0)
    assert open_range_list == valid_response

    :gen_tcp.send(socket, "LISTGROUP fun.times 5-7\r\n")
    {:ok, closed_range_list} = :gen_tcp.recv(socket, 0)
    assert closed_range_list == "211 5 5 10 fun.times\r\n5\r\n6\r\n.\r\n"

    :gen_tcp.send(socket, "LISTGROUP fun.times 7-5\r\n")
    {:ok, invalid_range_list} = :gen_tcp.recv(socket, 0)
    assert invalid_range_list == "211 5 5 10 fun.times\r\n.\r\n"

    quit(socket)
  end

end
