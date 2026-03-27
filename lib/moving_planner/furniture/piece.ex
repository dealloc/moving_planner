defmodule MovingPlanner.Furniture.Piece do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses [:pending, :disassembled, :in_transit, :arrived, :assembled]

  schema "furniture" do
    field :name, :string
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :notes, :string

    belongs_to :room, MovingPlanner.Rooms.Room

    timestamps(type: :utc_datetime)
  end

  def changeset(piece, attrs) do
    piece
    |> cast(attrs, [:name, :room_id, :status, :notes])
    |> validate_required([:name, :status])
  end

  def statuses, do: @statuses
end
