defmodule MovingPlannerWeb.FurnitureLive.Index do
  use MovingPlannerWeb, :live_view

  alias MovingPlanner.Furniture
  alias MovingPlanner.Rooms

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Furniture",
       current_page: :furniture,
       pieces: Furniture.list_pieces(),
       form: nil
     )}
  end

  def handle_params(_params, _uri, %{assigns: %{live_action: :new}} = socket) do
    {:noreply, assign(socket, form: to_form(Furniture.change_piece()))}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, form: nil)}
  end

  def handle_event("save_piece", %{"piece" => params}, socket) do
    case Furniture.create_piece(params) do
      {:ok, piece} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{piece.name} added.")
         |> push_patch(to: ~p"/furniture")
         |> assign(pieces: Furniture.list_pieces())}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("cycle_status", %{"id" => id}, socket) do
    piece = Furniture.get_piece!(id)

    case Furniture.cycle_status(piece) do
      {:ok, _} ->
        {:noreply, assign(socket, pieces: Furniture.list_pieces())}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update status.")}
    end
  end

  def handle_event("delete_piece", %{"id" => id}, socket) do
    piece = Furniture.get_piece!(id)

    case Furniture.delete_piece(piece) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{piece.name} deleted.")
         |> assign(pieces: Furniture.list_pieces())}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete.")}
    end
  end

  defp status_badge_class(:pending), do: "badge-ghost"
  defp status_badge_class(:disassembled), do: "badge-warning"
  defp status_badge_class(:in_transit), do: "badge-info"
  defp status_badge_class(:arrived), do: "badge-success"
  defp status_badge_class(:assembled), do: "badge-primary"

  defp status_label(:pending), do: "pending"
  defp status_label(:disassembled), do: "disassembled"
  defp status_label(:in_transit), do: "in transit"
  defp status_label(:arrived), do: "arrived"
  defp status_label(:assembled), do: "assembled"

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_page={@current_page}>
      <div class="space-y-4">
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold">Furniture</h1>
          <.link navigate={~p"/furniture/new"} class="btn btn-primary btn-sm">
            <.icon name="hero-plus" class="size-4" /> New Furniture
          </.link>
        </div>

        <%!-- New furniture modal --%>
        <div :if={@live_action == :new} class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg mb-4">New Furniture</h3>
            <.form for={@form} phx-submit="save_piece" class="space-y-4">
              <div class="form-control">
                <label class="label label-text">Name</label>
                <input
                  type="text"
                  name={@form[:name].name}
                  value={@form[:name].value}
                  class="input input-bordered input-sm"
                  placeholder="e.g. Sofa, Bed frame, Wardrobe"
                  autofocus
                />
                <p :for={err <- @form[:name].errors} class="text-error text-xs mt-1">
                  {translate_error(err)}
                </p>
              </div>
              <div class="form-control">
                <label class="label label-text">Room (optional)</label>
                <select name={@form[:room_id].name} class="select select-bordered select-sm">
                  <option value="">— no room —</option>
                  <option
                    :for={{name, id} <- Rooms.list_rooms_for_select()}
                    value={id}
                    selected={to_string(@form[:room_id].value) == to_string(id)}
                  >
                    {name}
                  </option>
                </select>
              </div>
              <div class="form-control">
                <label class="label label-text">Notes (optional)</label>
                <textarea
                  name={@form[:notes].name}
                  class="textarea textarea-bordered textarea-sm"
                  rows="2"
                  placeholder="Disassembly notes, dimensions, etc."
                >{@form[:notes].value}</textarea>
              </div>
              <div class="modal-action">
                <button type="submit" class="btn btn-primary">Add Furniture</button>
                <.link navigate={~p"/furniture"} class="btn btn-ghost">Cancel</.link>
              </div>
            </.form>
          </div>
          <.link navigate={~p"/furniture"} class="modal-backdrop"></.link>
        </div>

        <%!-- Table --%>
        <div class="overflow-x-auto">
          <table class="table table-zebra table-sm">
            <thead>
              <tr>
                <th>Name</th>
                <th>Room</th>
                <th>Status</th>
                <th>Notes</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={piece <- @pieces} id={"piece-#{piece.id}"}>
                <td class="font-medium">{piece.name}</td>
                <td>
                  <span :if={piece.room} class="badge badge-outline badge-sm">
                    {piece.room.letter}
                  </span>
                  {if piece.room, do: piece.room.name, else: "—"}
                </td>
                <td>
                  <button
                    class={["badge cursor-pointer", status_badge_class(piece.status)]}
                    phx-click="cycle_status"
                    phx-value-id={piece.id}
                    title="Tap to advance status"
                  >
                    {status_label(piece.status)}
                  </button>
                </td>
                <td class="text-base-content/60 text-sm max-w-xs truncate">
                  {piece.notes || ""}
                </td>
                <td>
                  <button
                    class="btn btn-ghost btn-xs text-error"
                    phx-click="delete_piece"
                    phx-value-id={piece.id}
                    data-confirm={"Delete #{piece.name}?"}
                  >
                    <.icon name="hero-trash" class="size-3" />
                  </button>
                </td>
              </tr>
              <tr :if={@pieces == []}>
                <td colspan="5" class="text-center text-base-content/50 py-12">
                  No furniture yet.
                  <.link navigate={~p"/furniture/new"} class="link">Add your first piece.</.link>
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
