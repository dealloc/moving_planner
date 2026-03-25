defmodule MovingPlanner.Rooms do
  import Ecto.Query
  alias MovingPlanner.Repo
  alias MovingPlanner.Rooms.Room

  @n_letter "N"

  def list_rooms(opts \\ []) do
    exclude_n = Keyword.get(opts, :exclude_n, false)

    Room
    |> maybe_exclude_n(exclude_n)
    |> order_by([r], r.name)
    |> Repo.all()
  end

  def list_rooms_for_select do
    Room
    |> order_by([r], r.name)
    |> Repo.all()
    |> Enum.map(&{&1.name, &1.id})
  end

  def get_room!(id), do: Repo.get!(Room, id)

  def get_room_by_letter(letter) when is_binary(letter) do
    Repo.get_by(Room, letter: String.upcase(letter))
  end

  def get_n_room! do
    Repo.get_by!(Room, letter: @n_letter)
  end

  def create_room(attrs) do
    %Room{}
    |> Room.changeset(attrs)
    |> Repo.insert()
  end

  def update_room(%Room{} = room, attrs) do
    room
    |> Room.changeset(attrs)
    |> Repo.update()
  end

  def delete_room(%Room{} = room) do
    box_count =
      Repo.aggregate(from(b in MovingPlanner.Inventory.Box, where: b.room_id == ^room.id), :count)

    if box_count > 0 do
      {:error, :has_boxes}
    else
      Repo.delete(room)
    end
  end

  def change_room(%Room{} = room \\ %Room{}, attrs \\ %{}) do
    Room.changeset(room, attrs)
  end

  def box_count_per_room do
    from(b in MovingPlanner.Inventory.Box,
      group_by: b.room_id,
      select: {b.room_id, count(b.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  defp maybe_exclude_n(query, true) do
    where(query, [r], r.letter != @n_letter)
  end

  defp maybe_exclude_n(query, _), do: query
end
