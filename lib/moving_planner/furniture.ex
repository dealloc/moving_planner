defmodule MovingPlanner.Furniture do
  import Ecto.Query

  alias MovingPlanner.Repo
  alias MovingPlanner.Furniture.Piece

  @pubsub MovingPlanner.PubSub
  @topic "furniture"

  def subscribe, do: Phoenix.PubSub.subscribe(@pubsub, @topic)

  @next_status %{
    pending: :disassembled,
    disassembled: :in_transit,
    in_transit: :arrived,
    arrived: :assembled,
    assembled: :pending
  }

  def list_pieces do
    Piece
    |> preload(:room)
    |> order_by([p], p.name)
    |> Repo.all()
  end

  def get_piece!(id) do
    Piece
    |> preload(:room)
    |> Repo.get!(id)
  end

  def create_piece(attrs) do
    %Piece{}
    |> Piece.changeset(attrs)
    |> Repo.insert()
    |> tap_broadcast()
  end

  def update_piece(%Piece{} = piece, attrs) do
    piece
    |> Piece.changeset(attrs)
    |> Repo.update()
    |> tap_broadcast()
  end

  def delete_piece(%Piece{} = piece), do: Repo.delete(piece) |> tap_broadcast()

  def change_piece(%Piece{} = piece \\ %Piece{}, attrs \\ %{}) do
    Piece.changeset(piece, attrs)
  end

  def cycle_status(%Piece{} = piece) do
    next = Map.fetch!(@next_status, piece.status)
    update_piece(piece, %{status: next})
  end

  def set_status(%Piece{} = piece, status) do
    update_piece(piece, %{status: status})
  end

  defp tap_broadcast({:ok, _} = result) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, :updated)
    result
  end

  defp tap_broadcast(result), do: result
end
