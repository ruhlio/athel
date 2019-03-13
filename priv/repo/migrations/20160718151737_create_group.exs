defmodule Athel.Repo.Migrations.CreateGroup do
  use Ecto.Migration

  def up do
    execute "CREATE TYPE group_status AS ENUM ('y', 'n', 'm')"

    create table(:groups, primary_key: false) do
      add :name, :string, size: 128, primary_key: true
      add :description, :string, size: 256, null: false
      add :low_watermark, :integer, null: false
      add :high_watermark, :integer, null: false
      add :status, :group_status, null: false

      timestamps()
    end
  end

  def down do
    drop table(:groups)
    execute "DROP TYPE group_status"
  end

end
