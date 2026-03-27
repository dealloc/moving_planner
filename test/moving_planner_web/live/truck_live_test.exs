defmodule MovingPlannerWeb.TruckLiveTest do
  use MovingPlannerWeb.ConnCase

  import Phoenix.LiveViewTest

  alias MovingPlanner.Inventory
  alias MovingPlanner.Furniture
  alias MovingPlanner.Rooms

  setup %{conn: conn} do
    conn = init_test_session(conn, %{authenticated: true})
    {:ok, conn: conn}
  end

  defp insert_room do
    {:ok, room} = Rooms.create_room(%{name: "Living Room", letter: "L"})
    room
  end

  defp insert_box(room) do
    {:ok, box} = Inventory.create_box(%{"room_id" => room.id})
    box
  end

  defp insert_piece(attrs) do
    {:ok, piece} = Furniture.create_piece(Enum.into(attrs, %{name: "Sofa"}))
    piece
  end

  describe "depart screen" do
    test "renders boxes tab by default", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/truck/depart")
      assert html =~ "Boxes"
      assert html =~ "Furniture"
    end

    test "shows unloaded box with DEPART button", %{conn: conn} do
      room = insert_room()
      box = insert_box(room)
      {:ok, _view, html} = live(conn, ~p"/truck/depart")
      assert html =~ box.serial |> Integer.to_string() |> String.pad_leading(3, "0")
      assert html =~ "DEPART"
    end

    test "departing a box sets departed_at", %{conn: conn} do
      room = insert_room()
      box = insert_box(room)
      {:ok, view, _html} = live(conn, ~p"/truck/depart")

      view
      |> element("[phx-click='depart_box'][phx-value-id='#{box.id}']")
      |> render_click()

      assert Inventory.get_box!(box.id).departed_at != nil
    end

    test "departed box sinks to bottom of list", %{conn: conn} do
      room = insert_room()
      box1 = insert_box(room)
      box2 = insert_box(room)
      Inventory.depart_box(Inventory.get_box!(box1.id))

      {:ok, _view, html} = live(conn, ~p"/truck/depart")
      code1 = "B-L-#{box1.serial |> Integer.to_string() |> String.pad_leading(3, "0")}"
      code2 = "B-L-#{box2.serial |> Integer.to_string() |> String.pad_leading(3, "0")}"
      {pos1, _} = :binary.match(html, code1)
      {pos2, _} = :binary.match(html, code2)
      assert pos2 < pos1
    end

    test "furniture tab shows pieces", %{conn: conn} do
      insert_piece(%{name: "Big Sofa"})
      {:ok, view, _html} = live(conn, ~p"/truck/depart")

      html =
        view
        |> element("[phx-click='switch_tab'][phx-value-tab='furniture']")
        |> render_click()

      assert html =~ "Big Sofa"
    end

    test "departing a piece sets status to in_transit", %{conn: conn} do
      piece = insert_piece(%{name: "Armchair"})
      {:ok, view, _html} = live(conn, ~p"/truck/depart")

      view
      |> element("[phx-click='switch_tab'][phx-value-tab='furniture']")
      |> render_click()

      view
      |> element("[phx-click='depart_piece'][phx-value-id='#{piece.id}']")
      |> render_click()

      assert Furniture.get_piece!(piece.id).status == :in_transit
    end

    test "search filters boxes by code", %{conn: conn} do
      room = insert_room()
      insert_box(room)
      {:ok, view, _html} = live(conn, ~p"/truck/depart")

      html =
        view
        |> element("input[name='search']")
        |> render_change(%{search: "ZZZZZ"})

      refute html =~ "B-L-"
    end
  end

  describe "arrive screen" do
    test "renders arrive heading", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/truck/arrive")
      assert html =~ "Arriving"
    end

    test "arriving a box sets arrived_at", %{conn: conn} do
      room = insert_room()
      box = insert_box(room)
      Inventory.depart_box(Inventory.get_box!(box.id))

      {:ok, view, _html} = live(conn, ~p"/truck/arrive")

      view
      |> element("[phx-click='arrive_box'][phx-value-id='#{box.id}']")
      |> render_click()

      assert Inventory.get_box!(box.id).arrived_at != nil
    end

    test "arriving a piece sets status to arrived", %{conn: conn} do
      piece = insert_piece(%{name: "Sofa"})
      Furniture.set_status(piece, :in_transit)
      piece = Furniture.get_piece!(piece.id)

      {:ok, view, _html} = live(conn, ~p"/truck/arrive")

      view
      |> element("[phx-click='switch_tab'][phx-value-tab='furniture']")
      |> render_click()

      view
      |> element("[phx-click='arrive_piece'][phx-value-id='#{piece.id}']")
      |> render_click()

      assert Furniture.get_piece!(piece.id).status == :arrived
    end
  end
end
