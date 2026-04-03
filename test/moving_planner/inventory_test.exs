defmodule MovingPlanner.InventoryTest do
  use MovingPlanner.DataCase

  alias MovingPlanner.Inventory
  alias MovingPlanner.Rooms

  defp insert_room(attrs \\ %{}) do
    unique = System.unique_integer([:positive, :monotonic])
    # Encode as base-36 style (digits only for simplicity, max 3 chars: 000-999)
    # Use modulo 900 offset by 100 to stay 3-digit decimal, all valid chars
    letter = Integer.to_string(rem(unique, 900) + 100)
    name = "Room #{unique}"
    {:ok, room} = Rooms.create_room(Enum.into(attrs, %{name: name, letter: letter}))
    room
  end

  defp insert_box(attrs \\ %{}) do
    room = insert_room()
    {:ok, box} = Inventory.create_box(Enum.into(attrs, %{"room_id" => room.id}))
    box
  end

  defp insert_item(box, attrs) do
    {:ok, item} = Inventory.create_item(Enum.into(attrs, %{name: "Widget", box_id: box.id}))
    item
  end

  defp depart(box) do
    {:ok, box} = Inventory.depart_box(box)
    box
  end

  defp arrive(box) do
    {:ok, box} = Inventory.arrive_box(box)
    box
  end

  describe "list_items/1 with box_status filter" do
    test "box_status: :not_departed returns only items in un-departed boxes" do
      box_origin = insert_box()
      box_transit = insert_box() |> depart()
      box_arrived = insert_box() |> depart() |> arrive()

      item_origin = insert_item(box_origin, %{name: "At origin"})
      insert_item(box_transit, %{name: "In transit"})
      insert_item(box_arrived, %{name: "Arrived"})

      result = Inventory.list_items(box_status: :not_departed)
      ids = Enum.map(result, & &1.id)

      assert item_origin.id in ids
      assert length(ids) == 1
    end

    test "box_status: :in_transit returns only items in departed-but-not-arrived boxes" do
      box_origin = insert_box()
      box_transit = insert_box() |> depart()
      box_arrived = insert_box() |> depart() |> arrive()

      insert_item(box_origin, %{name: "At origin"})
      item_transit = insert_item(box_transit, %{name: "In transit"})
      insert_item(box_arrived, %{name: "Arrived"})

      result = Inventory.list_items(box_status: :in_transit)
      ids = Enum.map(result, & &1.id)

      assert item_transit.id in ids
      assert length(ids) == 1
    end

    test "box_status: :arrived returns only items in arrived boxes" do
      box_origin = insert_box()
      box_transit = insert_box() |> depart()
      box_arrived = insert_box() |> depart() |> arrive()

      insert_item(box_origin, %{name: "At origin"})
      insert_item(box_transit, %{name: "In transit"})
      item_arrived = insert_item(box_arrived, %{name: "Arrived"})

      result = Inventory.list_items(box_status: :arrived)
      ids = Enum.map(result, & &1.id)

      assert item_arrived.id in ids
      assert length(ids) == 1
    end

    test "no box_status filter returns all items" do
      box_origin = insert_box()
      box_arrived = insert_box() |> depart() |> arrive()

      insert_item(box_origin, %{name: "At origin"})
      insert_item(box_arrived, %{name: "Arrived"})

      result = Inventory.list_items()
      assert length(result) == 2
    end
  end
end
