defmodule Athel.Repo.Migrations.CreateGroup do
  use Ecto.Migration

  def up do
    execute "create type group_status as enum ('y', 'n', 'm')"

    create table(:groups) do
      add :name, :string, size: 128, null: false
      add :description, :string, size: 256, null: false
      add :low_watermark, :integer, null: false
      add :high_watermark, :integer, null: false
      add :status, :group_status, null: false

      timestamps()
    end

    create unique_index(:groups, [:name])
  end

  def down do
    drop table(:groups)
    execute "drop type group_status"
  end

end
