defmodule MovingPlannerWeb.PageControllerTest do
  use MovingPlannerWeb.ConnCase

  test "GET / redirects to login when unauthenticated", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/login"
  end

  test "GET / renders dashboard when authenticated", %{conn: conn} do
    conn = conn |> init_test_session(%{"authenticated" => true}) |> get(~p"/")
    assert html_response(conn, 200) =~ "Dashboard"
  end
end
