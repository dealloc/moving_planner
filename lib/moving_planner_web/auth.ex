defmodule MovingPlannerWeb.Auth do
  import Plug.Conn

  def on_mount(:require_auth, _params, session, socket) do
    if session["authenticated"] == true do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: "/login")}
    end
  end

  def require_auth(conn, _opts) do
    if get_session(conn, :authenticated) do
      conn
    else
      conn
      |> Phoenix.Controller.redirect(to: "/login")
      |> halt()
    end
  end

  def valid_password?(password) when is_binary(password) do
    configured = Application.get_env(:moving_planner, :auth_password, "")
    Plug.Crypto.secure_compare(password, configured)
  end
end
