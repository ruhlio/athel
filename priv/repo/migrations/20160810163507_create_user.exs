defmodule Athel.Repo.Migrations.CreateUser do
  use Ecto.Migration

  def up do
    execute "CREATE TYPE user_status AS ENUM ('active', 'pending', 'locked')"

    create table(:users, primary_key: false) do
      add :username, :string, size: 64, primary_key: true
      add :email, :string, null: true, size: 255
      add :hashed_password, :binary, null: false
      add :salt, :binary, null: false
      add :public_key, :text, null: true
      add :status, :user_status, null: false

      timestamps()
    end

    create unique_index(:users, [:email])
  end

  def down do
    drop unique_index(:users, [:email])
    drop table(:users)
    execute "DROP TYPE user_status"
  end
end
