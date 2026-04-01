defmodule MovingPlannerWeb.ItemsLive.Index do
  use MovingPlannerWeb, :live_view

  alias MovingPlanner.Inventory
  alias MovingPlanner.Inventory.Box
  alias MovingPlanner.Rooms

  def mount(_params, _session, socket) do
    if connected?(socket), do: Inventory.subscribe()

    {:ok,
     assign(socket,
       page_title: "Items",
       current_page: :items,
       items: Inventory.list_items(),
       tags: Inventory.list_tags(),
       rooms: Rooms.list_rooms(exclude_n: true),
       search: "",
       selected_tag_ids: [],
       filter_room_id: nil
     )}
  end

  def handle_info(
        :updated,
        %{assigns: %{search: "", selected_tag_ids: [], filter_room_id: nil}} = socket
      ) do
    {:noreply, assign(socket, items: Inventory.list_items(), tags: Inventory.list_tags())}
  end

  def handle_info(:updated, socket), do: {:noreply, socket}

  def handle_event("search", %{"search" => term}, socket) do
    items =
      Inventory.list_items(
        search: term,
        tag_ids: socket.assigns.selected_tag_ids,
        room_id: socket.assigns.filter_room_id
      )

    {:noreply, assign(socket, items: items, search: term)}
  end

  def handle_event("filter_room", %{"room_id" => room_id}, socket) do
    room_id = if room_id == "", do: nil, else: String.to_integer(room_id)

    items =
      Inventory.list_items(
        search: socket.assigns.search,
        tag_ids: socket.assigns.selected_tag_ids,
        room_id: room_id
      )

    {:noreply, assign(socket, items: items, filter_room_id: room_id)}
  end

  def handle_event("toggle_tag", %{"id" => id}, socket) do
    tag_id = String.to_integer(id)

    selected =
      if tag_id in socket.assigns.selected_tag_ids do
        List.delete(socket.assigns.selected_tag_ids, tag_id)
      else
        [tag_id | socket.assigns.selected_tag_ids]
      end

    items =
      Inventory.list_items(
        search: socket.assigns.search,
        tag_ids: selected,
        room_id: socket.assigns.filter_room_id
      )

    {:noreply, assign(socket, items: items, selected_tag_ids: selected)}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     assign(socket,
       items: Inventory.list_items(),
       search: "",
       selected_tag_ids: [],
       filter_room_id: nil
     )}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_page={@current_page}>
      <div class="space-y-4">
        <h1 class="text-2xl font-bold">Items</h1>

        <%!-- Search and filters --%>
        <div class="flex flex-wrap gap-2 items-end">
          <form phx-change="search" phx-submit="search" class="form-control flex-1 min-w-48">
            <input
              type="text"
              class="input input-bordered input-sm"
              placeholder="Search items…"
              value={@search}
              phx-debounce="500"
              name="search"
            />
          </form>
          <select
            phx-change="filter_room"
            name="room_id"
            class="select select-bordered select-sm"
          >
            <option value="">All rooms</option>
            <option
              :for={room <- @rooms}
              value={room.id}
              selected={@filter_room_id == room.id}
            >
              {room.name}
            </option>
          </select>
          <button
            :if={@search != "" or @selected_tag_ids != [] or @filter_room_id != nil}
            class="btn btn-ghost btn-sm"
            phx-click="clear_filters"
          >
            Clear
          </button>
        </div>

        <%!-- Tag filter pills --%>
        <div :if={@tags != []} class="flex flex-wrap gap-1">
          <button
            :for={tag <- @tags}
            class={[
              "badge cursor-pointer",
              if(tag.id in @selected_tag_ids, do: "badge-primary", else: "badge-outline")
            ]}
            phx-click="toggle_tag"
            phx-value-id={tag.id}
          >
            {tag.name}
          </button>
        </div>

        <%!-- Items count --%>
        <p class="text-sm text-base-content/50">
          {length(@items)} item{if length(@items) != 1, do: "s"}
        </p>

        <%!-- Items table --%>
        <div class="overflow-x-auto">
          <table class="table table-zebra table-sm">
            <thead>
              <tr>
                <th>Name</th>
                <th>Box</th>
                <th>Room</th>
                <th>Tags</th>
                <th>Fragile</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={item <- @items} id={"item-#{item.id}"}>
                <td>{item.name}</td>
                <td>
                  <.link navigate={~p"/boxes/#{item.box_id}"} class="font-mono link link-hover">
                    {Box.compute_code(item.box)}
                  </.link>
                </td>
                <td>
                  <span class="badge badge-outline badge-sm">{item.box.room.letter}</span>
                  {item.box.room.name}
                </td>
                <td>
                  <div class="flex flex-wrap gap-1">
                    <span :for={tag <- item.tags} class="badge badge-outline badge-sm">
                      {tag.name}
                    </span>
                  </div>
                </td>
                <td>
                  <span :if={item.fragile} class="badge badge-warning badge-sm">fragile</span>
                </td>
              </tr>
              <tr :if={@items == []}>
                <td colspan="5" class="text-center text-base-content/50 py-12">
                  No items found.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
