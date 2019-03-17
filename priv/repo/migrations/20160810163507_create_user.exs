defmodule Athel.Repo.Migrations.CreateUser do
  use Ecto.Migration

  def up do
    execute "CREATE TYPE user_status AS ENUM ('active', 'pending', 'locked')"

    create table(:users, primary_key: false) do
      add :email, :string, size: 255, primary_key: true
      add :hashed_password, :binary, null: true
      add :salt, :binary, null: true
      add :public_key, :text, null: true
      add :status, :user_status, null: false

      timestamps()
    end
  end

  def down do
    drop table(:users)
    execute "DROP TYPE user_status"
  end
end
