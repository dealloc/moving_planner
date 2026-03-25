defmodule MovingPlanner.Data do
  import Ecto.Query

  alias MovingPlanner.Repo
  alias MovingPlanner.Rooms.Room
  alias MovingPlanner.Inventory.{Box, Item, Tag}
  alias MovingPlanner.Planning.Todo

  @current_version 1

  # ---------------------------------------------------------------------------
  # Export
  # ---------------------------------------------------------------------------

  def export_json do
    rooms = Repo.all(from r in Room, order_by: r.id)
    boxes = Repo.all(from b in Box, order_by: b.id) |> Repo.preload(items: :tags)
    todos = Repo.all(from t in Todo, order_by: t.id)

    %{
      version: @current_version,
      exported_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      rooms: Enum.map(rooms, &serialize_room/1),
      boxes: Enum.map(boxes, &serialize_box/1),
      todos: Enum.map(todos, &serialize_todo/1)
    }
    |> Jason.encode!(pretty: true)
  end

  # ---------------------------------------------------------------------------
  # Import
  # ---------------------------------------------------------------------------

  def import_json(json_string) do
    with {:ok, data} <- Jason.decode(json_string) |> map_json_error(),
         :ok <- validate_version(data) do
      Repo.transaction(fn ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        # Clear in FK-safe order
        Repo.delete_all("item_tags")
        Repo.delete_all(Item)
        Repo.delete_all(Box)
        Repo.delete_all(Todo)
        Repo.delete_all(Room)

        for r <- Map.get(data, "rooms", []) do
          Repo.insert!(%Room{
            id: r["id"],
            name: r["name"],
            letter: r["letter"],
            inserted_at: now,
            updated_at: now
          })
        end

        for b <- Map.get(data, "boxes", []) do
          Repo.insert!(%Box{
            id: b["id"],
            serial: b["serial"],
            room_id: b["room_id"],
            departed_at: parse_datetime(b["departed_at"]),
            arrived_at: parse_datetime(b["arrived_at"]),
            inserted_at: now,
            updated_at: now
          })

          for i <- Map.get(b, "items", []) do
            Repo.insert!(%Item{
              id: i["id"],
              name: i["name"],
              fragile: i["fragile"] || false,
              box_id: b["id"],
              inserted_at: now,
              updated_at: now
            })

            for tag_name <- Map.get(i, "tags", []) do
              tag =
                case Repo.get_by(Tag, name: tag_name) do
                  nil -> Repo.insert!(%Tag{name: tag_name, inserted_at: now, updated_at: now})
                  existing -> existing
                end

              Repo.insert_all("item_tags", [%{item_id: i["id"], tag_id: tag.id}])
            end
          end
        end

        for t <- Map.get(data, "todos", []) do
          Repo.insert!(%Todo{
            id: t["id"],
            title: t["title"],
            status: String.to_existing_atom(t["status"]),
            notes: t["notes"],
            due_date: parse_date(t["due_date"]),
            inserted_at: now,
            updated_at: now
          })
        end

        counts = %{
          rooms: length(Map.get(data, "rooms", [])),
          boxes: length(Map.get(data, "boxes", [])),
          todos: length(Map.get(data, "todos", []))
        }

        counts
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # Serializers
  # ---------------------------------------------------------------------------

  defp serialize_room(r), do: %{id: r.id, name: r.name, letter: r.letter}

  defp serialize_box(b) do
    %{
      id: b.id,
      serial: b.serial,
      room_id: b.room_id,
      departed_at: dt_to_string(b.departed_at),
      arrived_at: dt_to_string(b.arrived_at),
      items: Enum.map(b.items, &serialize_item/1)
    }
  end

  defp serialize_item(i) do
    %{
      id: i.id,
      name: i.name,
      fragile: i.fragile,
      tags: Enum.map(i.tags, & &1.name)
    }
  end

  defp serialize_todo(t) do
    %{
      id: t.id,
      title: t.title,
      status: t.status,
      notes: t.notes,
      due_date: date_to_string(t.due_date)
    }
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp map_json_error({:ok, data}), do: {:ok, data}
  defp map_json_error({:error, e}), do: {:error, "invalid JSON: #{Exception.message(e)}"}

  defp validate_version(%{"version" => v}) when v <= @current_version, do: :ok
  defp validate_version(%{"version" => v}), do: {:error, "unsupported export version #{v}"}
  defp validate_version(_), do: {:error, "missing version field"}

  defp dt_to_string(nil), do: nil
  defp dt_to_string(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  defp date_to_string(nil), do: nil
  defp date_to_string(%Date{} = d), do: Date.to_iso8601(d)

  defp parse_datetime(nil), do: nil

  defp parse_datetime(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      _ -> nil
    end
  end

  defp parse_date(nil), do: nil

  defp parse_date(str) do
    case Date.from_iso8601(str) do
      {:ok, d} -> d
      _ -> nil
    end
  end
end
