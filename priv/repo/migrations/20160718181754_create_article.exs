defmodule Athel.Repo.Migrations.CreateArticle do
  use Ecto.Migration

  def up do
    execute "CREATE TYPE article_status AS ENUM ('active', 'banned')"

    create table(:articles, primary_key: false) do
      add :message_id, :string, primary_key: true, size: 192
      add :parent_message_id, :string, size: 192
      add :from, :string, null: true
      add :subject, :string, null: false
      add :date, :utc_datetime, null: false
      add :content_type, :string, null: false
      add :status, :article_status, null: false
      add :headers, :map, null: false
      add :body, :text, null: false

      timestamps()
    end

    create index(:articles, :parent_message_id)

    create table(:articles_to_groups, primary_key: false) do
      add :message_id, references(:articles, column: :message_id, type: :string)
      add :group_name, references(:groups, column: :name, type: :string)
    end

  end

  def down do
    drop table(:articles_to_groups)
    drop index(:articles, :parent_message_id)
    drop table(:articles)
    execute "DROP TYPE article_status"
  end

end
