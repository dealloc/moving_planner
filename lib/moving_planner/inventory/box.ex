defmodule MovingPlanner.Inventory.Box do
  use Ecto.Schema
  import Ecto.Changeset

  schema "boxes" do
    field :serial, :integer
    field :departed_at, :utc_datetime
    field :arrived_at, :utc_datetime
    field :code, :string

    field :fragile, :boolean, virtual: true
    field :sealed, :boolean, virtual: true, default: false

    belongs_to :room, MovingPlanner.Rooms.Room
    has_many :items, MovingPlanner.Inventory.Item, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  def changeset(box, attrs) do
    box
    |> cast(attrs, [:room_id, :departed_at, :arrived_at, :code])
    |> validate_arrived_requires_departed()
  end

  defp validate_arrived_requires_departed(changeset) do
    arrived_at = get_field(changeset, :arrived_at)
    departed_at = get_field(changeset, :departed_at)

    if arrived_at && is_nil(departed_at) do
      add_error(changeset, :arrived_at, "cannot be set without a departure time")
    else
      changeset
    end
  end

  @doc "Computes the display code for a box with a preloaded room."
  def compute_code(%__MODULE__{serial: serial, room: %{letter: letter}})
      when not is_nil(serial) do
    "B-#{letter}-#{serial |> Integer.to_string() |> String.pad_leading(3, "0")}"
  end

  def compute_code(%__MODULE__{}), do: nil

  @doc "Parses a box code string like 'B-LIV-001'. Returns {:ok, letter, serial} or :error."
  def parse_code(code) when is_binary(code) do
    case Regex.run(~r/^B-([A-Z0-9]{1,3})-(\d+)$/i, String.upcase(code)) do
      [_, letter, serial_str] -> {:ok, String.upcase(letter), String.to_integer(serial_str)}
      _ -> :error
    end
  end

  def parse_code(_), do: :error
end
