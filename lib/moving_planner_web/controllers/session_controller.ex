defmodule MovingPlannerWeb.SessionController do
  use MovingPlannerWeb, :controller

  def new(conn, _params) do
    render(conn, :new, error: nil)
  end

  def create(conn, %{"password" => password}) do
    if MovingPlannerWeb.Auth.valid_password?(password) do
      conn
      |> put_session(:authenticated, true)
      |> redirect(to: ~p"/")
    else
      render(conn, :new, error: "Incorrect password.")
    end
  end

  def delete(conn, _params) do
    conn
    |> delete_session(:authenticated)
    |> redirect(to: ~p"/login")
  end
end
