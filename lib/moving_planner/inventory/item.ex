defmodule MovingPlanner.Inventory.Item do
  use Ecto.Schema
  import Ecto.Changeset

  schema "items" do
    field :name, :string
    field :fragile, :boolean, default: false

    belongs_to :box, MovingPlanner.Inventory.Box

    many_to_many :tags, MovingPlanner.Inventory.Tag,
      join_through: "item_tags",
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:name, :fragile, :box_id])
    |> validate_required([:name, :box_id])
  end

  def with_tags_changeset(item, attrs, tags) do
    item
    |> changeset(attrs)
    |> put_assoc(:tags, tags)
  end
end
