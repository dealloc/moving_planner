defmodule MovingPlanner.Repo.Migrations.CreateItemTags do
  use Ecto.Migration

  def change do
    create table(:item_tags, primary_key: false) do
      add :item_id, references(:items, on_delete: :delete_all), null: false, primary_key: true
      add :tag_id, references(:tags, on_delete: :delete_all), null: false, primary_key: true
    end

    create index(:item_tags, [:item_id])
    create index(:item_tags, [:tag_id])
  end
end
