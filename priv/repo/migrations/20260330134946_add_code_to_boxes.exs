defmodule MovingPlanner.Repo.Migrations.AddCodeToBoxes do
  use Ecto.Migration

  def change do
    alter table(:boxes) do
      add :code, :string
    end
  end
end
