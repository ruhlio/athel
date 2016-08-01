defmodule Athel.Nntp.ServerTest do
  use ExUnit.Case

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

  test "capabilities", %{socket: socket} do
    :gen_tcp.send(socket, "CAPABILITIES\r\n")
    {:ok, capabilities} = :gen_tcp.recv(socket, 0)
    assert capabilities == "101 Listing capabilities\r\nVERSION 2\r\nPOST\r\n.\r\n"

    quit(socket)
  end

end
