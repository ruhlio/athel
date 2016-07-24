defmodule Athel.Repo.Migrations.CreateGroup do
  use Ecto.Migration

  def up do
    execute "create type group_status as enum ('y', 'n', 'm')"
  end

  def down do
    execute "drop type group_status"
  end

  def change do
    create table(:groups) do
      add :name, :string, size: 128, null: false
      add :low_watermark, :integer, null: false
      add :high_watermark, :integer, null: false
      add :status, :group_status, size: 1, null: false

      timestamps()
    end

  end

end
