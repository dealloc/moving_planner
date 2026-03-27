defmodule MovingPlannerWeb.DataControllerTest do
  use MovingPlannerWeb.ConnCase

  alias MovingPlanner.Repo
  alias MovingPlanner.Rooms.Room

  defp authed(conn) do
    init_test_session(conn, %{"authenticated" => true})
  end

  defp json_upload(json) do
    path = System.tmp_dir!() |> Path.join("test_import_#{System.unique_integer()}.json")
    File.write!(path, json)
    on_exit(fn -> File.rm(path) end)
    %Plug.Upload{path: path, filename: "backup.json", content_type: "application/json"}
  end

  # ---------------------------------------------------------------------------
  # GET /data
  # ---------------------------------------------------------------------------

  describe "GET /data" do
    test "redirects when unauthenticated", %{conn: conn} do
      conn = get(conn, ~p"/data")
      assert redirected_to(conn) == "/login"
    end

    test "renders page when authenticated", %{conn: conn} do
      conn = conn |> authed() |> get(~p"/data")
      assert html_response(conn, 200) =~ "Import / Export"
    end
  end

  # ---------------------------------------------------------------------------
  # GET /export
  # ---------------------------------------------------------------------------

  describe "GET /export" do
    test "redirects when unauthenticated", %{conn: conn} do
      conn = get(conn, ~p"/export")
      assert redirected_to(conn) == "/login"
    end

    test "returns JSON attachment when authenticated", %{conn: conn} do
      conn = conn |> authed() |> get(~p"/export")
      assert response_content_type(conn, :json)
      assert get_resp_header(conn, "content-disposition") |> hd() =~ "attachment"
      assert get_resp_header(conn, "content-disposition") |> hd() =~ ".json"
    end

    test "export filename includes today's date", %{conn: conn} do
      conn = conn |> authed() |> get(~p"/export")
      date = Date.utc_today() |> to_string()
      assert get_resp_header(conn, "content-disposition") |> hd() =~ date
    end

    test "export body is valid JSON with version field", %{conn: conn} do
      conn = conn |> authed() |> get(~p"/export")
      data = json_response(conn, 200)
      assert data["version"] == 2
      assert is_list(data["rooms"])
      assert is_list(data["boxes"])
      assert is_list(data["todos"])
    end
  end

  # ---------------------------------------------------------------------------
  # POST /import
  # ---------------------------------------------------------------------------

  describe "POST /import" do
    test "redirects when unauthenticated", %{conn: conn} do
      upload = json_upload(~s({"version":1,"rooms":[],"boxes":[],"todos":[]}))
      conn = post(conn, ~p"/import", %{"file" => upload})
      assert redirected_to(conn) == "/login"
    end

    test "imports valid JSON and redirects to dashboard", %{conn: conn} do
      json =
        Jason.encode!(%{
          version: 1,
          rooms: [%{id: 10, name: "Test Room", letter: "T"}],
          boxes: [],
          todos: []
        })

      conn = conn |> authed() |> post(~p"/import", %{"file" => json_upload(json)})
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Imported"
    end

    test "shows import counts in flash message", %{conn: conn} do
      json =
        Jason.encode!(%{
          version: 1,
          rooms: [%{id: 1, name: "R", letter: "A"}, %{id: 2, name: "S", letter: "B"}],
          boxes: [],
          todos: [%{id: 1, title: "T", status: "pending", notes: nil, due_date: nil}]
        })

      conn = conn |> authed() |> post(~p"/import", %{"file" => json_upload(json)})
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "2 rooms"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "1 todos"
    end

    test "shows error flash for invalid JSON", %{conn: conn} do
      conn = conn |> authed() |> post(~p"/import", %{"file" => json_upload("not json")})
      assert redirected_to(conn) == ~p"/data"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Import failed"
    end

    test "shows error flash for unsupported version", %{conn: conn} do
      json = Jason.encode!(%{version: 99, rooms: [], boxes: [], todos: []})
      conn = conn |> authed() |> post(~p"/import", %{"file" => json_upload(json)})
      assert redirected_to(conn) == ~p"/data"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "unsupported export version"
    end

    test "shows error when no file uploaded", %{conn: conn} do
      conn = conn |> authed() |> post(~p"/import", %{})
      assert redirected_to(conn) == ~p"/data"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "No file uploaded"
    end

    test "actually persists imported data", %{conn: conn} do
      json =
        Jason.encode!(%{
          version: 1,
          rooms: [%{id: 42, name: "Garage", letter: "G"}],
          boxes: [],
          todos: []
        })

      conn |> authed() |> post(~p"/import", %{"file" => json_upload(json)})
      assert Repo.get_by(Room, letter: "G")
    end
  end
end
