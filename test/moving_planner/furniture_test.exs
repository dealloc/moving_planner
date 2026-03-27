defmodule MovingPlanner.FurnitureTest do
  use MovingPlanner.DataCase

  alias MovingPlanner.Furniture
  alias MovingPlanner.Furniture.Piece
  alias MovingPlanner.Rooms

  defp insert_room(attrs \\ %{}) do
    {:ok, room} =
      Rooms.create_room(Enum.into(attrs, %{name: "Living Room", letter: "L"}))

    room
  end

  defp insert_piece(attrs \\ %{}) do
    {:ok, piece} = Furniture.create_piece(Enum.into(attrs, %{name: "Sofa"}))
    piece
  end

  describe "list_pieces/0" do
    test "returns all pieces ordered by name" do
      insert_piece(%{name: "Wardrobe"})
      insert_piece(%{name: "Armchair"})
      names = Furniture.list_pieces() |> Enum.map(& &1.name)
      assert names == ["Armchair", "Wardrobe"]
    end

    test "preloads room" do
      room = insert_room()
      insert_piece(%{room_id: room.id})
      [piece] = Furniture.list_pieces()
      assert piece.room.name == "Living Room"
    end
  end

  describe "get_piece!/1" do
    test "returns piece by id" do
      piece = insert_piece()
      found = Furniture.get_piece!(piece.id)
      assert found.id == piece.id
    end

    test "raises if not found" do
      assert_raise Ecto.NoResultsError, fn -> Furniture.get_piece!(0) end
    end
  end

  describe "create_piece/1" do
    test "creates with valid attrs" do
      room = insert_room()

      assert {:ok, %Piece{name: "Sofa"}} =
               Furniture.create_piece(%{name: "Sofa", room_id: room.id})
    end

    test "allows nil room_id" do
      assert {:ok, %Piece{room_id: nil}} = Furniture.create_piece(%{name: "Sofa"})
    end

    test "defaults status to pending" do
      {:ok, piece} = Furniture.create_piece(%{name: "Sofa"})
      assert piece.status == :pending
    end

    test "returns error changeset when name missing" do
      assert {:error, %Ecto.Changeset{}} = Furniture.create_piece(%{})
    end
  end

  describe "update_piece/2" do
    test "updates name" do
      piece = insert_piece()
      {:ok, updated} = Furniture.update_piece(piece, %{name: "New Name"})
      assert updated.name == "New Name"
    end
  end

  describe "delete_piece/1" do
    test "deletes the piece" do
      piece = insert_piece()
      {:ok, _} = Furniture.delete_piece(piece)
      assert Furniture.list_pieces() == []
    end
  end

  describe "cycle_status/1" do
    test "advances pending to disassembled" do
      piece = insert_piece()
      assert piece.status == :pending
      {:ok, updated} = Furniture.cycle_status(piece)
      assert updated.status == :disassembled
    end

    test "advances disassembled to in_transit" do
      piece = insert_piece()
      {:ok, piece} = Furniture.update_piece(piece, %{status: :disassembled})
      {:ok, updated} = Furniture.cycle_status(piece)
      assert updated.status == :in_transit
    end

    test "wraps assembled back to pending" do
      piece = insert_piece()
      {:ok, piece} = Furniture.update_piece(piece, %{status: :assembled})
      {:ok, updated} = Furniture.cycle_status(piece)
      assert updated.status == :pending
    end
  end

  describe "set_status/2" do
    test "sets status to a specific value" do
      piece = insert_piece()
      {:ok, updated} = Furniture.set_status(piece, :in_transit)
      assert updated.status == :in_transit
    end

    test "can set to arrived" do
      piece = insert_piece()
      {:ok, updated} = Furniture.set_status(piece, :arrived)
      assert updated.status == :arrived
    end
  end
end
