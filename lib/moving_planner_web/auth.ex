defmodule MovingPlannerWeb.Auth do
  import Phoenix.LiveView

  def on_mount(:require_auth, _params, session, socket) do
    if session["authenticated"] == true do
      {:cont, socket}
    else
      {:halt, redirect(socket, to: "/login")}
    end
  end

  def valid_password?(password) when is_binary(password) do
    configured = Application.get_env(:moving_planner, :auth_password, "")
    Plug.Crypto.secure_compare(password, configured)
  end
end
