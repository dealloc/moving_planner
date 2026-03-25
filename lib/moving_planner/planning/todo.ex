defmodule MovingPlanner.Planning.Todo do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses [:pending, :in_progress, :done]

  schema "todos" do
    field :title, :string
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :notes, :string
    field :due_date, :date

    timestamps(type: :utc_datetime)
  end

  def changeset(todo, attrs) do
    todo
    |> cast(attrs, [:title, :status, :notes, :due_date])
    |> validate_required([:title, :status])
  end

  def statuses, do: @statuses
end
