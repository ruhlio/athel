defmodule Athel.Repo.Migrations.CreateArticle do
  use Ecto.Migration

  def up do
    execute "create type article_status as enum ('active', 'banned')"

    create table(:articles, primary_key: false) do
      add :message_id, :string, primary_key: true, size: 192
      add :parent_message_id, references(:articles, column: :message_id, type: :string), size: 192
      add :from, :string, null: true
      add :subject, :string, null: false
      add :date, :datetime, null: false
      add :content_type, :string, null: false
      add :body, :text, null: false

      add :status, :article_status, null: false

      timestamps()
    end

    create table(:articles_to_groups, primary_key: false) do
      add :message_id, references(:articles, column: :message_id, type: :string)
      add :group_id, references(:groups)
    end

  end

  def down do
    drop table(:articles_to_groups)
    drop table(:articles)
    execute "drop type article_status"
  end

end
