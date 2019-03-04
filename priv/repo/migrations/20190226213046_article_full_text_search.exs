defmodule Athel.Repo.Migrations.ArticleFullTextSearch do
  use Ecto.Migration

  def up do
    alter table(:articles) do
      add :language, :string, null: false, default: "english"
    end

    execute """
CREATE MATERIALIZED VIEW article_search_index AS
  SELECT message_id,
         parent_message_id,
         "from",
         subject,
         date,
         status,
         language,
         setweight(to_tsvector(language::regconfig, subject), 'A') || setweight(to_tsvector(language::regconfig, body), 'B') AS document
  FROM articles
"""
    execute "CREATE INDEX index_search_articles ON article_search_index USING GIN(document)"
  end

  def down do
    execute "DROP INDEX index_search_articles"
    execute "DROP MATERIALIZED VIEW article_search_index"

    alter table(:articles) do
      remove :language
    end
  end
end
