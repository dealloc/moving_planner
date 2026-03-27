defmodule MovingPlanner.Rooms.Room do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rooms" do
    field :name, :string
    field :letter, :string

    has_many :boxes, MovingPlanner.Inventory.Box, foreign_key: :room_id

    timestamps(type: :utc_datetime)
  end

  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :letter])
    |> validate_required([:name, :letter])
    |> update_change(:letter, &String.upcase/1)
    |> validate_length(:letter, min: 1, max: 3)
    |> validate_format(:letter, ~r/^[A-Z0-9]+$/, message: "must be letters or digits only")
    |> validate_exclusion(:letter, ["N"], message: "reserved for unassigned boxes")
    |> unique_constraint(:letter)
  end
end
