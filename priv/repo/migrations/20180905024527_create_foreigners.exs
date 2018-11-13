defmodule Athel.Repo.Migrations.CreateForeigners do
  use Ecto.Migration

  def change do
    create table(:foreigners) do
      add :hostname, :string, null: false
      add :port, :integer, null: false
      add :username, :string
      add :password, :binary
      add :interval, :integer

      timestamps()
    end

  end
end
