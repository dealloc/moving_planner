defmodule MovingPlanner.Repo.Migrations.CreateBoxes do
  use Ecto.Migration

  def change do
    create table(:boxes) do
      add :serial, :integer, null: false
      add :room_id, references(:rooms, on_delete: :restrict), null: true
      add :departed_at, :utc_datetime, null: true
      add :arrived_at, :utc_datetime, null: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:boxes, [:serial])
    create index(:boxes, [:room_id])
  end
end
