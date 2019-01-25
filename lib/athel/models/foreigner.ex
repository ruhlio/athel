defmodule Athel.Foreigner do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Inspect, except: [:password]}
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

defimpl String.Chars, for: Athel.Foreigner do
  def to_string(f) do
    "#{f.hostname}:#{f.port}"
  end
end
