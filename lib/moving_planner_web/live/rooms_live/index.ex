defmodule MovingPlannerWeb.RoomsLive.Index do
  use MovingPlannerWeb, :live_view

  alias MovingPlanner.Rooms

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Rooms",
       current_page: :rooms,
       rooms: list_rooms_with_counts(),
       form: nil,
       editing_id: nil
     )}
  end

  def handle_event("new_room", _params, socket) do
    {:noreply, assign(socket, form: to_form(Rooms.change_room()), editing_id: nil)}
  end

  def handle_event("edit_room", %{"id" => id}, socket) do
    room = Rooms.get_room!(id)
    {:noreply, assign(socket, form: to_form(Rooms.change_room(room)), editing_id: room.id)}
  end

  def handle_event("cancel_form", _params, socket) do
    {:noreply, assign(socket, form: nil, editing_id: nil)}
  end

  def handle_event("save_room", %{"room" => params}, socket) do
    result =
      if socket.assigns.editing_id do
        room = Rooms.get_room!(socket.assigns.editing_id)
        Rooms.update_room(room, params)
      else
        Rooms.create_room(params)
      end

    case result do
      {:ok, _room} ->
        {:noreply,
         socket
         |> put_flash(:info, "Room saved.")
         |> assign(form: nil, editing_id: nil, rooms: list_rooms_with_counts())}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("delete_room", %{"id" => id}, socket) do
    room = Rooms.get_room!(id)

    case Rooms.delete_room(room) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Room deleted.")
         |> assign(rooms: list_rooms_with_counts())}

      {:error, :has_boxes} ->
        {:noreply, put_flash(socket, :error, "Cannot delete a room that has boxes assigned.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete room.")}
    end
  end

  defp list_rooms_with_counts do
    counts = Rooms.box_count_per_room()

    Rooms.list_rooms(exclude_n: true)
    |> Enum.map(&Map.put(&1, :box_count, Map.get(counts, &1.id, 0)))
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_page={@current_page}>
      <div class="space-y-4">
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold">Rooms</h1>
          <button :if={!@form} class="btn btn-primary btn-sm" phx-click="new_room">
            <.icon name="hero-plus" class="size-4" /> Add Room
          </button>
        </div>

        <%!-- New/Edit form --%>
        <div :if={@form && !@editing_id} class="card bg-base-200 shadow">
          <div class="card-body">
            <h2 class="card-title text-base">New Room</h2>
            <.form for={@form} phx-submit="save_room" class="flex gap-2 items-end flex-wrap">
              <div class="form-control">
                <label class="label label-text">Letter (1–3 chars)</label>
                <input
                  type="text"
                  name={@form[:letter].name}
                  value={@form[:letter].value}
                  maxlength="3"
                  class="input input-bordered input-sm w-24 uppercase"
                  placeholder="e.g. LIV"
                />
                <p :for={err <- @form[:letter].errors} class="text-error text-xs mt-1">
                  {translate_error(err)}
                </p>
              </div>
              <div class="form-control flex-1 min-w-48">
                <label class="label label-text">Name</label>
                <input
                  type="text"
                  name={@form[:name].name}
                  value={@form[:name].value}
                  class="input input-bordered input-sm"
                  placeholder="e.g. Living Room"
                />
                <p :for={err <- @form[:name].errors} class="text-error text-xs mt-1">
                  {translate_error(err)}
                </p>
              </div>
              <div class="flex gap-2">
                <button type="submit" class="btn btn-primary btn-sm">Save</button>
                <button type="button" class="btn btn-ghost btn-sm" phx-click="cancel_form">
                  Cancel
                </button>
              </div>
            </.form>
          </div>
        </div>

        <%!-- Rooms table --%>
        <div class="overflow-x-auto">
          <table class="table table-zebra">
            <thead>
              <tr>
                <th>Letter</th>
                <th>Name</th>
                <th>Boxes</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={room <- @rooms} id={"room-#{room.id}"}>
                <td>
                  <span class="badge badge-outline font-mono">{room.letter}</span>
                </td>
                <td :if={@editing_id != room.id}>{room.name}</td>
                <td :if={@editing_id == room.id} colspan="2">
                  <.form
                    for={@form}
                    phx-submit="save_room"
                    class="flex gap-2 items-center flex-wrap"
                  >
                    <input
                      type="text"
                      name={@form[:letter].name}
                      value={@form[:letter].value}
                      maxlength="3"
                      class="input input-bordered input-xs w-20 uppercase"
                    />
                    <input
                      type="text"
                      name={@form[:name].name}
                      value={@form[:name].value}
                      class="input input-bordered input-xs flex-1"
                    />
                    <button type="submit" class="btn btn-primary btn-xs">Save</button>
                    <button type="button" class="btn btn-ghost btn-xs" phx-click="cancel_form">
                      Cancel
                    </button>
                  </.form>
                </td>
                <td :if={@editing_id != room.id}>{room.box_count}</td>
                <td :if={@editing_id != room.id}>
                  <div class="flex gap-1 justify-end">
                    <button
                      class="btn btn-ghost btn-xs"
                      phx-click="edit_room"
                      phx-value-id={room.id}
                    >
                      <.icon name="hero-pencil" class="size-3" />
                    </button>
                    <button
                      class="btn btn-ghost btn-xs text-error"
                      phx-click="delete_room"
                      phx-value-id={room.id}
                      data-confirm={"Delete room #{room.name}?"}
                    >
                      <.icon name="hero-trash" class="size-3" />
                    </button>
                  </div>
                </td>
              </tr>
              <tr :if={@rooms == []}>
                <td colspan="4" class="text-center text-base-content/50 py-8">
                  No rooms yet. Add one to get started.
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
