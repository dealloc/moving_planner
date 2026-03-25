defmodule MovingPlanner.Repo.Migrations.CreateTodos do
  use Ecto.Migration

  def change do
    create table(:todos) do
      add :title, :string, null: false
      add :status, :string, default: "pending", null: false
      add :notes, :text, null: true
      add :due_date, :date, null: true

      timestamps(type: :utc_datetime)
    end
  end
end
