defmodule Athel.User do
  use Ecto.Schema

  import Ecto.Changeset

  schema "users" do
    field :username, :string
    field :email, :string
    field :hashed_password, :binary
    field :salt, :binary

    timestamps()
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:username, :email, :hashed_password, :salt])
    |> validate_required([:username, :email, :hashed_password, :salt])
    |> validate_format(:username, ~r/^[0-9A-Z_]{3,64}$/i)
    |> validate_length(:email, max: 255)
    |> validate_format(:email, ~r/^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i)
    |> validate_length(:salt, min: 8)
    |> validate_hash(:hashed_password)
  end

  defp validate_hash(changeset, field) do
    case get_field(changeset, field) do
      nil -> changeset
      hash ->
        case Multihash.decode(hash) do
          {:ok, _} -> changeset
          {:error, _} -> add_error(changeset, field, "invalid multihash")
        end
    end
  end

end
