defmodule Athel.Repo.Migrations.CreateRole do
  use Ecto.Migration

  def change do
    create table(:roles, primary_key: false) do
      add :name, :string, primary_key: true
      add :user_email, references(:users, column: :email, type: :string), primary_key: true
      add :group_name, references(:groups, column: :name, type: :string), primary_key: true

      timestamps()
    end
  end
end
