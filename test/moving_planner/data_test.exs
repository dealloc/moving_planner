defmodule MovingPlanner.DataTest do
  use MovingPlanner.DataCase

  alias MovingPlanner.Data
  alias MovingPlanner.Rooms.Room
  alias MovingPlanner.Inventory.{Box, Item, Tag}
  alias MovingPlanner.Planning.Todo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp insert_room(attrs) do
    Repo.insert!(%Room{
      name: attrs[:name] || "Living Room",
      letter: attrs[:letter] || "L"
    })
  end

  defp insert_box(room, attrs) do
    Repo.insert!(%Box{
      serial: attrs[:serial] || 1,
      room_id: room.id,
      departed_at: attrs[:departed_at],
      arrived_at: attrs[:arrived_at]
    })
  end

  defp insert_item(box, attrs) do
    Repo.insert!(%Item{
      name: attrs[:name] || "Item",
      fragile: attrs[:fragile] || false,
      box_id: box.id
    })
  end

  defp insert_tag(name), do: Repo.insert!(%Tag{name: name})

  defp tag_item(item, tag) do
    Repo.insert_all("item_tags", [%{item_id: item.id, tag_id: tag.id}])
  end

  defp insert_todo(attrs) do
    Repo.insert!(%Todo{
      title: attrs[:title] || "Pack stuff",
      status: attrs[:status] || :pending,
      notes: attrs[:notes],
      due_date: attrs[:due_date]
    })
  end

  # ---------------------------------------------------------------------------
  # export_json/0
  # ---------------------------------------------------------------------------

  describe "export_json/0" do
    test "returns valid JSON" do
      json = Data.export_json()
      assert {:ok, _} = Jason.decode(json)
    end

    test "includes version and exported_at fields" do
      data = Data.export_json() |> Jason.decode!()
      assert data["version"] == 1
      assert is_binary(data["exported_at"])
    end

    test "exports rooms" do
      room = insert_room(name: "Kitchen", letter: "K")
      data = Data.export_json() |> Jason.decode!()

      room_data = Enum.find(data["rooms"], &(&1["id"] == room.id))
      assert room_data["name"] == "Kitchen"
      assert room_data["letter"] == "K"
    end

    test "exports boxes with items and tags" do
      room = insert_room(name: "Living Room", letter: "L")
      box = insert_box(room, serial: 7, departed_at: ~U[2026-03-01 10:00:00Z])
      item = insert_item(box, name: "TV", fragile: true)
      tag = insert_tag("electronics")
      tag_item(item, tag)

      data = Data.export_json() |> Jason.decode!()
      box_data = Enum.find(data["boxes"], &(&1["id"] == box.id))

      assert box_data["serial"] == 7
      assert box_data["room_id"] == room.id
      assert box_data["departed_at"] == "2026-03-01T10:00:00Z"
      assert box_data["arrived_at"] == nil

      [item_data] = box_data["items"]
      assert item_data["name"] == "TV"
      assert item_data["fragile"] == true
      assert item_data["tags"] == ["electronics"]
    end

    test "exports todos with all fields" do
      insert_todo(title: "Label boxes", status: :in_progress, due_date: ~D[2026-04-01])
      data = Data.export_json() |> Jason.decode!()

      [todo_data | _] = data["todos"]
      assert todo_data["title"] == "Label boxes"
      assert todo_data["status"] == "in_progress"
      assert todo_data["due_date"] == "2026-04-01"
    end

    test "exports empty collections when no data" do
      data = Data.export_json() |> Jason.decode!()
      # N room from migration is present, but no user rooms, boxes, or todos
      assert data["boxes"] == []
      assert data["todos"] == []
    end
  end

  # ---------------------------------------------------------------------------
  # import_json/1
  # ---------------------------------------------------------------------------

  describe "import_json/1" do
    test "returns error for invalid JSON" do
      assert {:error, _} = Data.import_json("not json")
    end

    test "returns error for missing version" do
      assert {:error, "missing version field"} = Data.import_json(~s({"rooms": []}))
    end

    test "returns error for unsupported version" do
      json = Jason.encode!(%{version: 99, rooms: [], boxes: [], todos: []})
      assert {:error, "unsupported export version 99"} = Data.import_json(json)
    end

    test "imports rooms" do
      json =
        Jason.encode!(%{
          version: 1,
          rooms: [%{id: 10, name: "Bedroom", letter: "B"}],
          boxes: [],
          todos: []
        })

      assert {:ok, _} = Data.import_json(json)
      assert Repo.get_by(Room, letter: "B")
    end

    test "imports boxes with items and tags" do
      json =
        Jason.encode!(%{
          version: 1,
          rooms: [%{id: 1, name: "Living", letter: "L"}],
          boxes: [
            %{
              id: 1,
              serial: 3,
              room_id: 1,
              departed_at: nil,
              arrived_at: nil,
              items: [
                %{id: 1, name: "Lamp", fragile: false, tags: ["decor", "fragile"]}
              ]
            }
          ],
          todos: []
        })

      assert {:ok, _} = Data.import_json(json)

      box = Repo.get_by!(Box, serial: 3)
      assert box.room_id != nil

      item = Repo.get_by!(Item, name: "Lamp")
      item = Repo.preload(item, :tags)
      tag_names = Enum.map(item.tags, & &1.name) |> Enum.sort()
      assert tag_names == ["decor", "fragile"]
    end

    test "imports todos with all fields" do
      json =
        Jason.encode!(%{
          version: 1,
          rooms: [],
          boxes: [],
          todos: [
            %{id: 1, title: "Buy boxes", status: "pending", notes: "lots", due_date: "2026-04-01"}
          ]
        })

      assert {:ok, _} = Data.import_json(json)

      todo = Repo.get_by!(Todo, title: "Buy boxes")
      assert todo.status == :pending
      assert todo.notes == "lots"
      assert todo.due_date == ~D[2026-04-01]
    end

    test "clears existing data before importing" do
      insert_room(name: "Old Room", letter: "O")
      insert_todo(title: "Old todo")

      json =
        Jason.encode!(%{
          version: 1,
          rooms: [%{id: 99, name: "New Room", letter: "X"}],
          boxes: [],
          todos: [%{id: 99, title: "New todo", status: "done", notes: nil, due_date: nil}]
        })

      assert {:ok, _} = Data.import_json(json)

      refute Repo.get_by(Room, letter: "O")
      refute Repo.get_by(Todo, title: "Old todo")
      assert Repo.get_by(Room, letter: "X")
      assert Repo.get_by(Todo, title: "New todo")
    end

    test "returns counts of imported records" do
      json =
        Jason.encode!(%{
          version: 1,
          rooms: [%{id: 1, name: "R1", letter: "A"}, %{id: 2, name: "R2", letter: "B"}],
          boxes: [
            %{id: 1, serial: 1, room_id: 1, departed_at: nil, arrived_at: nil, items: []}
          ],
          todos: [
            %{id: 1, title: "T1", status: "pending", notes: nil, due_date: nil}
          ]
        })

      assert {:ok, %{rooms: 2, boxes: 1, todos: 1}} = Data.import_json(json)
    end

    test "shared tags are deduplicated" do
      json =
        Jason.encode!(%{
          version: 1,
          rooms: [%{id: 1, name: "Room", letter: "R"}],
          boxes: [
            %{
              id: 1,
              serial: 1,
              room_id: 1,
              departed_at: nil,
              arrived_at: nil,
              items: [
                %{id: 1, name: "Item A", fragile: false, tags: ["fragile"]},
                %{id: 2, name: "Item B", fragile: false, tags: ["fragile"]}
              ]
            }
          ],
          todos: []
        })

      assert {:ok, _} = Data.import_json(json)
      assert Repo.aggregate(Tag, :count) == 1
    end

    test "round-trips data through export and import" do
      room = insert_room(name: "Kitchen", letter: "K")
      box = insert_box(room, serial: 5)
      item = insert_item(box, name: "Kettle", fragile: true)
      tag = insert_tag("appliance")
      tag_item(item, tag)
      insert_todo(title: "Pack kitchen", status: :in_progress)

      json = Data.export_json()

      # Clear manually to simulate a fresh import
      Repo.delete_all("item_tags")
      Repo.delete_all(Item)
      Repo.delete_all(Box)
      Repo.delete_all(Todo)
      Repo.delete_all(Room)

      assert {:ok, _} = Data.import_json(json)

      restored_room = Repo.get_by!(Room, letter: "K")
      assert restored_room.name == "Kitchen"

      restored_box = Repo.get_by!(Box, serial: 5)
      assert restored_box.room_id == restored_room.id

      restored_item = Repo.get_by!(Item, name: "Kettle") |> Repo.preload(:tags)
      assert restored_item.fragile == true
      assert [%Tag{name: "appliance"}] = restored_item.tags

      assert Repo.get_by(Todo, title: "Pack kitchen")
    end
  end
end
