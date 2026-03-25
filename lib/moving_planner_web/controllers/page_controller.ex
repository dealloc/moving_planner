defmodule MovingPlannerWeb.PageController do
  use MovingPlannerWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
