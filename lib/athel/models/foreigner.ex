defmodule Athel.Foreigner do
  use Ecto.Schema
  import Ecto.Changeset

  schema "foreigners" do
    field :hostname, :string
    field :port, :integer
    field :username, :string
    field :password, Athel.EncryptedBinaryField
    field :interval, :integer

    timestamps()
  end

  @doc false
  def changeset(foreigner, attrs) do
    foreigner
    |> cast(attrs, [:hostname, :port, :username, :password, :interval])
    |> validate_required([:hostname, :port, :interval])
  end
end
