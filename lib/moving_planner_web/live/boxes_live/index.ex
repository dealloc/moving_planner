defmodule MovingPlannerWeb.BoxesLive.Index do
  use MovingPlannerWeb, :live_view

  alias MovingPlanner.Inventory
  alias MovingPlanner.Inventory.Box
  alias MovingPlanner.Rooms

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Boxes",
       current_page: :boxes,
       boxes: Inventory.list_boxes(),
       rooms: Rooms.list_rooms(),
       filter_room_id: nil,
       filter_status: nil,
       filter_fragile: false,
       form: nil
     )}
  end

  def handle_params(_params, _uri, %{assigns: %{live_action: :new}} = socket) do
    {:noreply, assign(socket, form: to_form(Inventory.change_box()))}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, form: nil)}
  end

  def handle_event("filter", params, socket) do
    room_id =
      case params["room_id"] do
        "" -> nil
        nil -> nil
        id -> String.to_integer(id)
      end

    status =
      case params["status"] do
        "" -> nil
        nil -> nil
        s -> String.to_existing_atom(s)
      end

    fragile = params["fragile"] == "true"

    boxes = Inventory.list_boxes(room_id: room_id, status: status, fragile: if(fragile, do: true))

    {:noreply,
     assign(socket,
       boxes: boxes,
       filter_room_id: room_id,
       filter_status: status,
       filter_fragile: fragile
     )}
  end

  def handle_event("detect_room", %{"code" => code}, socket) do
    case Box.parse_code(code) do
      {:ok, letter, _serial} ->
        case Rooms.get_room_by_letter(letter) do
          nil ->
            {:noreply, socket}

          room ->
            cs = Inventory.change_box(%Box{}, %{room_id: room.id})
            {:noreply, assign(socket, form: to_form(cs))}
        end

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("save_box", %{"box" => params}, socket) do
    case Inventory.create_box(params) do
      {:ok, box} ->
        {:noreply,
         socket
         |> put_flash(:info, "Box #{box.code} created.")
         |> push_patch(to: ~p"/boxes")
         |> assign(boxes: reload_boxes(socket.assigns))}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("depart_box", %{"id" => id}, socket) do
    box = Inventory.get_box!(id)

    case Inventory.depart_box(box) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Box marked as departed.")
         |> assign(boxes: reload_boxes(socket.assigns))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update box.")}
    end
  end

  def handle_event("arrive_box", %{"id" => id}, socket) do
    box = Inventory.get_box!(id)

    case Inventory.arrive_box(box) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Box marked as arrived.")
         |> assign(boxes: reload_boxes(socket.assigns))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update box.")}
    end
  end

  def handle_event("delete_box", %{"id" => id}, socket) do
    box = Inventory.get_box!(id)

    case Inventory.delete_box(box) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Box deleted.")
         |> assign(boxes: reload_boxes(socket.assigns))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete box.")}
    end
  end

  defp reload_boxes(assigns) do
    Inventory.list_boxes(
      room_id: assigns.filter_room_id,
      status: assigns.filter_status,
      fragile: if(assigns.filter_fragile, do: true)
    )
  end

  defp box_status(%{arrived_at: a}) when not is_nil(a), do: {:arrived, "badge-success", "Arrived"}

  defp box_status(%{departed_at: d}) when not is_nil(d),
    do: {:in_transit, "badge-info", "In transit"}

  defp box_status(_), do: {:pending, "badge-ghost", "Not departed"}

  defp format_datetime(nil), do: ""
  defp format_datetime(%DateTime{} = dt), do: DateTime.to_string(dt)

  defp format_date(nil), do: "—"
  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d")

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_page={@current_page}>
      <div class="space-y-4">
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold">Boxes</h1>
          <.link navigate={~p"/boxes/new"} class="btn btn-primary btn-sm">
            <.icon name="hero-plus" class="size-4" /> New Box
          </.link>
        </div>

        <%!-- Filters --%>
        <div class="flex flex-wrap gap-2 items-end">
          <div class="form-control">
            <label class="label label-text">Room</label>
            <select
              class="select select-bordered select-sm"
              phx-change="filter"
              name="room_id"
              value={@filter_room_id}
            >
              <option value="">All rooms</option>
              <option :for={room <- @rooms} value={room.id} selected={@filter_room_id == room.id}>
                {room.name}
              </option>
            </select>
          </div>
          <div class="form-control">
            <label class="label label-text">Status</label>
            <select
              class="select select-bordered select-sm"
              phx-change="filter"
              name="status"
              value={@filter_status}
            >
              <option value="">All</option>
              <option value="not_departed" selected={@filter_status == :not_departed}>
                Not departed
              </option>
              <option value="in_transit" selected={@filter_status == :in_transit}>In transit</option>
              <option value="arrived" selected={@filter_status == :arrived}>Arrived</option>
            </select>
          </div>
          <label class="label cursor-pointer gap-2">
            <input
              type="checkbox"
              class="checkbox checkbox-sm checkbox-warning"
              phx-change="filter"
              name="fragile"
              value="true"
              checked={@filter_fragile}
            />
            <span class="label-text">Fragile only</span>
          </label>
        </div>

        <%!-- New box modal --%>
        <div :if={@live_action == :new} class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg mb-4">New Box</h3>
            <.form for={@form} phx-submit="save_box" class="space-y-4">
              <div class="form-control">
                <label class="label label-text">
                  Box Code (optional — auto-detects room)
                </label>
                <input
                  type="text"
                  class="input input-bordered input-sm font-mono uppercase"
                  placeholder="e.g. B-LIV-001"
                  phx-change="detect_room"
                  name="code"
                  value=""
                />
                <p class="text-xs text-base-content/50 mt-1">
                  Serial is assigned automatically. Code is for auto-detecting the room.
                </p>
              </div>
              <div class="form-control">
                <label class="label label-text">Destination Room</label>
                <select
                  name={@form[:room_id].name}
                  class="select select-bordered select-sm"
                >
                  <option
                    :for={{name, id} <- Rooms.list_rooms_for_select()}
                    value={id}
                    selected={to_string(@form[:room_id].value) == to_string(id)}
                  >
                    {name}
                  </option>
                </select>
              </div>
              <div class="modal-action">
                <button type="submit" class="btn btn-primary">Create Box</button>
                <.link navigate={~p"/boxes"} class="btn btn-ghost">Cancel</.link>
              </div>
            </.form>
          </div>
          <.link navigate={~p"/boxes"} class="modal-backdrop"></.link>
        </div>

        <%!-- Boxes table --%>
        <div class="overflow-x-auto">
          <table class="table table-zebra table-sm">
            <thead>
              <tr>
                <th>Code</th>
                <th>Room</th>
                <th>Items</th>
                <th>Fragile</th>
                <th>Status</th>
                <th>Departed</th>
                <th>Arrived</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={box <- @boxes} id={"box-#{box.id}"}>
                <td>
                  <.link navigate={~p"/boxes/#{box.id}"} class="font-mono font-medium link link-hover">
                    {box.code}
                  </.link>
                </td>
                <td>
                  <span class="badge badge-outline badge-sm">{box.room.letter}</span>
                  {box.room.name}
                </td>
                <td>{length(box.items)}</td>
                <td>
                  <span :if={box.fragile} class="badge badge-warning badge-sm">
                    <.icon name="hero-exclamation-triangle" class="size-3 mr-1" /> fragile
                  </span>
                </td>
                <td>
                  <% {_s, cls, label} = box_status(box) %>
                  <span class={["badge badge-sm", cls]}>{label}</span>
                </td>
                <td>
                  <time
                    :if={box.departed_at}
                    title={format_datetime(box.departed_at)}
                    class="cursor-help"
                  >
                    {format_date(box.departed_at)}
                  </time>
                  <span :if={!box.departed_at} class="text-base-content/30">—</span>
                </td>
                <td>
                  <time
                    :if={box.arrived_at}
                    title={format_datetime(box.arrived_at)}
                    class="cursor-help"
                  >
                    {format_date(box.arrived_at)}
                  </time>
                  <span :if={!box.arrived_at} class="text-base-content/30">—</span>
                </td>
                <td>
                  <div class="flex gap-1 justify-end">
                    <button
                      :if={!box.departed_at}
                      class="btn btn-ghost btn-xs"
                      phx-click="depart_box"
                      phx-value-id={box.id}
                      title="Mark as departed"
                    >
                      <.icon name="hero-truck" class="size-3" />
                    </button>
                    <button
                      :if={box.departed_at && !box.arrived_at}
                      class="btn btn-ghost btn-xs"
                      phx-click="arrive_box"
                      phx-value-id={box.id}
                      title="Mark as arrived"
                    >
                      <.icon name="hero-check-circle" class="size-3" />
                    </button>
                    <.link navigate={~p"/boxes/#{box.id}"} class="btn btn-ghost btn-xs" title="View">
                      <.icon name="hero-eye" class="size-3" />
                    </.link>
                    <button
                      class="btn btn-ghost btn-xs text-error"
                      phx-click="delete_box"
                      phx-value-id={box.id}
                      data-confirm={"Delete box #{box.code}? All items will be lost."}
                    >
                      <.icon name="hero-trash" class="size-3" />
                    </button>
                  </div>
                </td>
              </tr>
              <tr :if={@boxes == []}>
                <td colspan="8" class="text-center text-base-content/50 py-12">
                  No boxes yet.
                  <.link navigate={~p"/boxes/new"} class="link">Create your first box.</.link>
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
