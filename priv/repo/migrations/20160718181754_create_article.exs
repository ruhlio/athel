defmodule Athel.Repo.Migrations.CreateArticle do
  use Ecto.Migration

  def change do
    create table(:articles) do
      add :message_id, :string, primary_key: true, size: 192
      add :from, :string, null: true
      add :subject, :string, null: false
      add :date, :datetime, null: false
      add :reference, :string, null: true
      add :content_type, :string, null: false
      add :body, :text, null: false

      timestamps()
    end

    create unique_index(:articles, [:message_id])

    create table(:articles_to_groups, primary_key: false) do
      add :message_id, references(:articles, column: :message_id, type: :string)
      add :group_id, references(:groups)
    end

  end
end
