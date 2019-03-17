defmodule AthelWeb.AdminController do
  use AthelWeb, :controller

  alias Athel.Group

  def new_group(conn, _params) do
    render(conn, "new_group.html", changeset: Group.changeset(%Group{}))
  end

  def create_group(conn, %{"group" =>
                            %{
                              "name" => name,
                              "description" => description,
                              "status" => status}
                          }) do
    changeset = Group.changeset(%Group{},
      %{
        name: name,
        description: description,
        status: status,
        low_watermark: 0,
        high_watermark: 0
      })

    if changeset.valid? do
      Repo.insert!(changeset)
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
