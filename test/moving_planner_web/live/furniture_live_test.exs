defmodule MovingPlannerWeb.FurnitureLiveTest do
  use MovingPlannerWeb.ConnCase

  import Phoenix.LiveViewTest

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

  defp insert_piece(attrs \\ %{}) do
    {:ok, piece} = Furniture.create_piece(Enum.into(attrs, %{name: "Sofa"}))
    piece
  end

  describe "index" do
    test "renders list of pieces", %{conn: conn} do
      insert_piece(%{name: "Armchair"})
      {:ok, _view, html} = live(conn, ~p"/furniture")
      assert html =~ "Armchair"
    end

    test "shows status badge", %{conn: conn} do
      insert_piece(%{name: "Sofa"})
      {:ok, _view, html} = live(conn, ~p"/furniture")
      assert html =~ "pending"
    end

    test "shows empty state when no pieces", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/furniture")
      assert html =~ "No furniture yet"
    end
  end

  describe "create" do
    test "opens modal at /furniture/new", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/furniture/new")
      assert html =~ "New Furniture"
    end

    test "creates piece with valid attrs", %{conn: conn} do
      room = insert_room()
      {:ok, view, _html} = live(conn, ~p"/furniture/new")

      view
      |> form("form[phx-submit]", piece: %{name: "Desk", room_id: room.id})
      |> render_submit()

      assert [%{name: "Desk"}] = Furniture.list_pieces()
    end

    test "shows validation error when name blank", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/furniture/new")

      html =
        view
        |> form("form[phx-submit]", piece: %{name: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "cycle_status" do
    test "advances status on badge click", %{conn: conn} do
      piece = insert_piece()
      {:ok, view, _html} = live(conn, ~p"/furniture")

      view
      |> element("[phx-click='cycle_status'][phx-value-id='#{piece.id}']")
      |> render_click()

      assert Furniture.get_piece!(piece.id).status == :disassembled
    end
  end

  describe "delete" do
    test "removes piece from list", %{conn: conn} do
      piece = insert_piece(%{name: "Old Sofa"})
      {:ok, view, _html} = live(conn, ~p"/furniture")

      view
      |> element("[phx-click='delete_piece'][phx-value-id='#{piece.id}']")
      |> render_click()

      refute render(view) =~ "piece-#{piece.id}"
    end
  end
end
