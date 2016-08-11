defmodule Athel.Repo.Migrations.CreateUser do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :username, :string, nullable: false, size: 64
      add :email, :string, nullable: true, size: 255
      add :hashed_password, :binary, nullable: false
      add :salt, :binary, nullable: false

      timestamps()
    end

  end
end
