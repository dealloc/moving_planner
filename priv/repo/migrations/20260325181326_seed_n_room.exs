defmodule MovingPlanner.Repo.Migrations.SeedNRoom do
  use Ecto.Migration

  def change do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    execute(
      """
      INSERT INTO rooms (name, letter, inserted_at, updated_at)
      VALUES ('No Destination', 'N', '#{now}', '#{now}')
      ON CONFLICT (letter) DO NOTHING
      """,
      "DELETE FROM rooms WHERE letter = 'N'"
    )
  end
end
