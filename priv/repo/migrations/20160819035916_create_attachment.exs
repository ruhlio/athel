defmodule Athel.Repo.Migrations.CreateAttachment do
  use Ecto.Migration

  def change do
    create table(:attachments) do
      add :filename, :string
      add :type, :string
      add :hash, :binary
      add :content, :binary

      timestamps()
    end

    create table(:attachments_to_articles, primary_key: false) do
      add :attachment_id, references(:attachments)
      add :message_id, references(:articles, column: :message_id, type: :string)
    end

  end

end
