defmodule MovingPlanner.Repo.Migrations.CreateFurniture do
  use Ecto.Migration

  def change do
    create table(:furniture) do
      add :name, :string, null: false
      add :room_id, references(:rooms, on_delete: :nilify_all)
      add :status, :string, null: false, default: "pending"
      add :notes, :string

      timestamps(type: :utc_datetime)
    end

    create index(:furniture, [:room_id])
    create index(:furniture, [:status])
  end
end
