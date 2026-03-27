defmodule MovingPlannerWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use MovingPlannerWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders the app layout with a sidebar navigation.

  ## Examples

      <Layouts.app flash={@flash} current_page={:boxes}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :current_page, :atom, default: nil, doc: "the current page atom for active nav highlight"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="drawer lg:drawer-open">
      <input id="nav-drawer" type="checkbox" class="drawer-toggle" />

      <div class="drawer-content flex flex-col min-h-screen">
        <%!-- Mobile top bar --%>
        <div class="navbar bg-base-200 lg:hidden border-b border-base-300">
          <label for="nav-drawer" class="btn btn-ghost btn-sm">
            <.icon name="hero-bars-3" class="size-5" />
          </label>
          <span class="font-bold ml-2">Moving Planner</span>
          <div class="ml-auto mr-2">
            <.theme_toggle />
          </div>
        </div>

        <%!-- Page content --%>
        <main class="flex-1 p-4 lg:p-8">
          {render_slot(@inner_block)}
        </main>
      </div>

      <div class="drawer-side z-40">
        <label for="nav-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
        <aside class="w-64 min-h-full bg-base-200 border-r border-base-300 flex flex-col">
          <%!-- Logo --%>
          <div class="p-4 border-b border-base-300">
            <a href={~p"/"} class="flex items-center gap-2">
              <.icon name="hero-archive-box" class="size-6 text-primary" />
              <span class="font-bold text-lg">Moving Planner</span>
            </a>
            <p class="text-xs text-base-content/50 mt-1">
              {Application.get_env(:moving_planner, :location_from)} → {Application.get_env(
                :moving_planner,
                :location_to
              )}
            </p>
          </div>

          <%!-- Navigation links --%>
          <nav class="flex-1 p-3">
            <ul class="menu menu-sm gap-1 w-full">
              <li>
                <.link
                  navigate={~p"/"}
                  class={if @current_page == :dashboard, do: "active", else: ""}
                >
                  <.icon name="hero-squares-2x2" class="size-4" /> Dashboard
                </.link>
              </li>
              <li>
                <.link
                  navigate={~p"/boxes"}
                  class={if @current_page == :boxes, do: "active", else: ""}
                >
                  <.icon name="hero-archive-box" class="size-4" /> Boxes
                </.link>
              </li>
              <li>
                <.link
                  navigate={~p"/items"}
                  class={if @current_page == :items, do: "active", else: ""}
                >
                  <.icon name="hero-cube" class="size-4" /> Items
                </.link>
              </li>
              <li>
                <.link
                  navigate={~p"/rooms"}
                  class={if @current_page == :rooms, do: "active", else: ""}
                >
                  <.icon name="hero-home" class="size-4" /> Rooms
                </.link>
              </li>
              <li>
                <.link
                  navigate={~p"/todos"}
                  class={if @current_page == :todos, do: "active", else: ""}
                >
                  <.icon name="hero-check-circle" class="size-4" /> Todos
                </.link>
              </li>
              <li>
                <.link
                  navigate={~p"/furniture"}
                  class={if @current_page == :furniture, do: "active", else: ""}
                >
                  <.icon name="hero-table-cells" class="size-4" /> Furniture
                </.link>
              </li>
              <li class="menu-title text-base-content/30 text-xs pt-2">Move day</li>
              <li>
                <.link
                  navigate={~p"/truck/depart"}
                  class={if @current_page == :depart, do: "active", else: ""}
                >
                  <.icon name="hero-truck" class="size-4" /> Depart
                </.link>
              </li>
              <li>
                <.link
                  navigate={~p"/truck/arrive"}
                  class={if @current_page == :arrive, do: "active", else: ""}
                >
                  <.icon name="hero-check-circle" class="size-4" /> Arrive
                </.link>
              </li>
              <li>
                <.link
                  navigate={~p"/data"}
                  class={if @current_page == :data, do: "active", else: ""}
                >
                  <.icon name="hero-circle-stack" class="size-4" /> Import / Export
                </.link>
              </li>
            </ul>
          </nav>

          <%!-- Theme toggle + sign out --%>
          <div class="p-4 border-t border-base-300 flex items-center justify-between">
            <.theme_toggle />
            <.link
              href={~p"/login"}
              method="delete"
              class="btn btn-ghost btn-xs text-base-content/50"
              title="Sign out"
            >
              <.icon name="hero-arrow-right-on-rectangle" class="size-4" />
            </.link>
          </div>
        </aside>
      </div>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3 justify-center"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3 justify-center"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3 justify-center"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
