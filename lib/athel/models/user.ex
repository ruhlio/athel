defmodule Athel.User do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:email, :string, autogenerate: false}
  schema "users" do
    field :hashed_password, :binary
    field :salt, :binary
    field :status, :string

    field :public_key, :string
    field :decoded_public_key, :binary, virtual: true

    timestamps()
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:email, :hashed_password, :salt, :status, :public_key])
    |> validate_required([:email, :status])
    |> validate_length(:email, max: 255)
    |> validate_format(:email, ~r/^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i)
    |> validate_length(:salt, min: 8)
    |> validate_hash(:hashed_password)
    |> validate_inclusion(:status, ["active", "pending", "locked"])
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
