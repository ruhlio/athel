defmodule Athel.Repo.Migrations.CreateForeigners do
  use Ecto.Migration

  def change do
    create table(:foreigners) do
      add :url, :string, null: false
      add :username, :string
      add :password, :binary

      timestamps()
    end

  end
end