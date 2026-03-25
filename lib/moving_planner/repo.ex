defmodule MovingPlanner.Repo do
  use Ecto.Repo,
    otp_app: :moving_planner,
    adapter: Ecto.Adapters.SQLite3
end
