defmodule MovingPlanner.Repo.Migrations.CreateRooms do
  use Ecto.Migration

  def change do
    create table(:rooms) do
      add :name, :string, null: false
      add :letter, :string, size: 3, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:rooms, [:letter])
  end
end
