defmodule MovingPlanner.Repo.Migrations.CreateItems do
  use Ecto.Migration

  def change do
    create table(:items) do
      add :name, :string, null: false
      add :fragile, :boolean, default: false, null: false
      add :box_id, references(:boxes, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:items, [:box_id])
  end
end
