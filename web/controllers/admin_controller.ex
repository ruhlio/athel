defmodule Athel.AdminController do
  use Athel.Web, :controller

  alias Athel.Group

  def new_group(conn, _params) do
    render(conn, "new_group.html", changeset: Group.changeset(%Group{}))
  end

  def create_group(conn, %{"group" => %{"name" => name, "status" => status}}) do
      changeset = Group.changeset(%Group{}, %{
          "name" => name,
          "status" => status,
          "low_watermark" => 0,
          "high_watermark" => 0})

    if changeset.valid? do
      group = Repo.insert!(changeset)
      conn
      |> put_flash(:success, "Group created")
      |> redirect(to: "/")
    else
      conn
      |> put_flash(:error, "Please correct the errors and resubmit")
      |> render("new_group.html", changeset: changeset)
    end
  end

end
