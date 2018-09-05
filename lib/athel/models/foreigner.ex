defmodule Athel.Foreigner do
  use Ecto.Schema
  import Ecto.Changeset


  schema "foreigners" do
    field :url, :string
    field :username, :string
    field :password, Athel.EncryptedBinaryField

    timestamps()
  end

  @doc false
  def changeset(foreigner, attrs) do
    foreigner
    |> cast(attrs, [:url, :username, :password])
    |> validate_required([:url])
  end
end
