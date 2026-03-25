defmodule MovingPlannerWeb.DataController do
  use MovingPlannerWeb, :controller

  import MovingPlannerWeb.Auth, only: [require_auth: 2]

  alias MovingPlanner.Data

  plug :require_auth

  def index(conn, _params) do
    render(conn, :index)
  end

  def export(conn, _params) do
    json = Data.export_json()
    filename = "moving_planner_#{Date.utc_today()}.json"

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, json)
  end

  def import(conn, %{"file" => %Plug.Upload{path: path}}) do
    case File.read(path) do
      {:ok, contents} ->
        case Data.import_json(contents) do
          {:ok, counts} ->
            conn
            |> put_flash(
              :info,
              "Imported #{counts.rooms} rooms, #{counts.boxes} boxes, #{counts.todos} todos."
            )
            |> redirect(to: ~p"/")

          {:error, reason} ->
            conn
            |> put_flash(:error, "Import failed: #{reason}")
            |> redirect(to: ~p"/data")
        end

      {:error, _} ->
        conn
        |> put_flash(:error, "Could not read uploaded file.")
        |> redirect(to: ~p"/data")
    end
  end

  def import(conn, _params) do
    conn
    |> put_flash(:error, "No file uploaded.")
    |> redirect(to: ~p"/data")
  end
end
