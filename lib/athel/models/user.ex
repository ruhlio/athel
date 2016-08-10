defmodule Athel.User do
  use Athel.Web, :model

  schema "users" do
    field :username, :string
    field :email, :string
    field :encrypted_password, :string
    field :salt, :string

    timestamps()
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:username, :email, :encrypted_password, :salt])
    |> validate_required([:username, :email, :encrypted_password, :salt])
    |> validate_format(:username, ~r/^[0-9A-Z_]{3,64}$/i)
    |> validate_length(:email, max: 255)
    |> validate_format(:email, ~r/^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i)
  end
end
