defmodule MovingPlanner.Inventory do
  import Ecto.Query
  alias MovingPlanner.Repo
  alias MovingPlanner.Inventory.{Box, Item, Tag}
  alias MovingPlanner.Rooms

  # ---------------------------------------------------------------------------
  # Box queries
  # ---------------------------------------------------------------------------

  def list_boxes(opts \\ []) do
    Box
    |> maybe_filter_room(Keyword.get(opts, :room_id))
    |> maybe_filter_status(Keyword.get(opts, :status))
    |> preload([:room, items: :tags])
    |> order_by([b], b.serial)
    |> Repo.all()
    |> Enum.map(&populate_virtuals/1)
    |> maybe_filter_fragile(Keyword.get(opts, :fragile))
  end

  def get_box!(id) do
    Box
    |> preload([:room, items: :tags])
    |> Repo.get!(id)
    |> populate_virtuals()
  end

  def get_box_by_serial(serial) do
    Box
    |> preload([:room, items: :tags])
    |> Repo.get_by(serial: serial)
    |> case do
      nil -> nil
      box -> populate_virtuals(box)
    end
  end

  def box_stats do
    base =
      Repo.one(
        from b in Box,
          select: %{
            total: count(b.id),
            departed: count(b.departed_at),
            arrived: count(b.arrived_at)
          }
      )

    fragile_count =
      Repo.one(
        from b in Box,
          join: i in Item,
          on: i.box_id == b.id and i.fragile == true,
          select: count(b.id, :distinct)
      )

    Map.merge(base, %{
      fragile: fragile_count || 0,
      in_transit: (base.departed || 0) - (base.arrived || 0)
    })
  end

  # ---------------------------------------------------------------------------
  # Box mutations
  # ---------------------------------------------------------------------------

  def create_box(attrs) do
    Repo.transaction(fn ->
      serial = next_serial()
      n_room = Rooms.get_n_room!()
      room_id = Map.get(attrs, :room_id) || Map.get(attrs, "room_id") || n_room.id

      changeset =
        %Box{serial: serial}
        |> Box.changeset(Map.put(attrs, "room_id", room_id))

      case Repo.insert(changeset) do
        {:ok, box} ->
          box
          |> Repo.preload([:room, items: :tags])
          |> populate_virtuals()

        {:error, cs} ->
          Repo.rollback(cs)
      end
    end)
  end

  def update_box(%Box{} = box, attrs) do
    box
    |> Box.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated} ->
        {:ok,
         updated
         |> Repo.preload([:room, items: :tags], force: true)
         |> populate_virtuals()}

      error ->
        error
    end
  end

  def depart_box(%Box{} = box) do
    update_box(box, %{departed_at: DateTime.utc_now() |> DateTime.truncate(:second)})
  end

  def arrive_box(%Box{} = box) do
    update_box(box, %{arrived_at: DateTime.utc_now() |> DateTime.truncate(:second)})
  end

  def delete_box(%Box{} = box), do: Repo.delete(box)

  def change_box(%Box{} = box \\ %Box{}, attrs \\ %{}) do
    Box.changeset(box, attrs)
  end

  # ---------------------------------------------------------------------------
  # Item queries
  # ---------------------------------------------------------------------------

  def list_items(opts \\ []) do
    Item
    |> maybe_filter_box(Keyword.get(opts, :box_id))
    |> maybe_filter_tags(Keyword.get(opts, :tag_ids))
    |> maybe_search_items(Keyword.get(opts, :search))
    |> preload(box: :room, tags: [])
    |> order_by([i], i.name)
    |> Repo.all()
  end

  def get_item!(id) do
    Item
    |> preload(box: :room, tags: [])
    |> Repo.get!(id)
  end

  # ---------------------------------------------------------------------------
  # Item mutations
  # ---------------------------------------------------------------------------

  def create_item(attrs) do
    tags = resolve_tags(Map.get(attrs, :tags, Map.get(attrs, "tags", [])))

    %Item{}
    |> Item.with_tags_changeset(attrs, tags)
    |> Repo.insert()
  end

  def update_item(%Item{} = item, attrs) do
    tags = resolve_tags(Map.get(attrs, :tags, Map.get(attrs, "tags", [])))

    item
    |> Repo.preload(:tags)
    |> Item.with_tags_changeset(attrs, tags)
    |> Repo.update()
  end

  def delete_item(%Item{} = item), do: Repo.delete(item)

  def change_item(%Item{} = item \\ %Item{}, attrs \\ %{}) do
    Item.changeset(item, attrs)
  end

  # ---------------------------------------------------------------------------
  # Tag queries
  # ---------------------------------------------------------------------------

  def list_tags do
    Tag |> order_by([t], t.name) |> Repo.all()
  end

  def search_tags(term) when is_binary(term) and term != "" do
    search = "%#{term}%"
    Tag |> where([t], ilike(t.name, ^search)) |> order_by([t], t.name) |> Repo.all()
  end

  def search_tags(_), do: []

  def find_or_create_tag(name) when is_binary(name) do
    name = String.trim(name)

    case Repo.get_by(Tag, name: name) do
      %Tag{} = tag ->
        {:ok, tag}

      nil ->
        %Tag{}
        |> Tag.changeset(%{name: name})
        |> Repo.insert()
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp next_serial do
    max = Repo.one(from b in Box, select: max(b.serial))
    (max || 0) + 1
  end

  defp populate_virtuals(%Box{items: items} = box) when is_list(items) do
    fragile = Enum.any?(items, & &1.fragile)
    code = Box.compute_code(box)
    %{box | fragile: fragile, code: code}
  end

  defp populate_virtuals(%Box{} = box), do: box

  defp resolve_tags(tag_names) when is_list(tag_names) do
    tag_names
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn name ->
      case find_or_create_tag(name) do
        {:ok, tag} -> tag
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp resolve_tags(_), do: []

  defp maybe_filter_room(query, nil), do: query
  defp maybe_filter_room(query, room_id), do: where(query, [b], b.room_id == ^room_id)

  defp maybe_filter_status(query, nil), do: query
  defp maybe_filter_status(query, :all), do: query

  defp maybe_filter_status(query, :departed) do
    where(query, [b], not is_nil(b.departed_at) and is_nil(b.arrived_at))
  end

  defp maybe_filter_status(query, :arrived) do
    where(query, [b], not is_nil(b.arrived_at))
  end

  defp maybe_filter_status(query, :in_transit) do
    where(query, [b], not is_nil(b.departed_at) and is_nil(b.arrived_at))
  end

  defp maybe_filter_status(query, :not_departed) do
    where(query, [b], is_nil(b.departed_at))
  end

  defp maybe_filter_fragile(boxes, true), do: Enum.filter(boxes, & &1.fragile)
  defp maybe_filter_fragile(boxes, _), do: boxes

  defp maybe_filter_box(query, nil), do: query
  defp maybe_filter_box(query, box_id), do: where(query, [i], i.box_id == ^box_id)

  defp maybe_filter_tags(query, nil), do: query
  defp maybe_filter_tags(query, []), do: query

  defp maybe_filter_tags(query, tag_ids) do
    query
    |> join(:inner, [i], it in "item_tags", on: it.item_id == i.id)
    |> where([i, it], it.tag_id in ^tag_ids)
    |> distinct(true)
  end

  defp maybe_search_items(query, nil), do: query
  defp maybe_search_items(query, ""), do: query

  defp maybe_search_items(query, term) do
    search = "%#{term}%"
    where(query, [i], ilike(i.name, ^search))
  end
end
