defmodule Athel.Role do
  use Ecto.Schema
  import Ecto.Changeset

  alias Athel.User

  @type t :: %__MODULE__{}

  @primary_key false
  schema "roles" do
    field :name, :string
    field :group_name, :string

    belongs_to :user, User,
      foreign_key: :user_email,
      references: :email,
      type: :string
  end
end
