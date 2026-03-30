defmodule MovingPlannerWeb.BoxesLive.Show do
  use MovingPlannerWeb, :live_view

  alias MovingPlanner.Inventory
  alias MovingPlanner.Inventory.Item
  alias MovingPlanner.Rooms
  alias Phoenix.LiveView.JS

  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket), do: Inventory.subscribe()

    box = Inventory.get_box!(id)

    {:ok,
     assign(socket,
       page_title: "Box #{box.code}",
       current_page: :boxes,
       box: box,
       rooms: Rooms.list_rooms_for_select(),
       item_form: nil,
       editing_item_id: nil
     )}
  end

  def handle_info(:updated, socket) do
    box = Inventory.get_box!(socket.assigns.box.id)
    {:noreply, assign(socket, box: box, page_title: "Box #{box.code}")}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  def handle_event("new_item", _params, socket) do
    cs = Inventory.change_item(%Item{box_id: socket.assigns.box.id})
    {:noreply, assign(socket, item_form: to_form(cs), editing_item_id: nil)}
  end

  def handle_event("edit_item", %{"id" => id}, socket) do
    item = Inventory.get_item!(id)
    tag_names = item.tags |> Enum.map(& &1.name) |> Enum.join(", ")
    cs = Inventory.change_item(item)

    {:noreply,
     assign(socket, item_form: to_form(cs), editing_item_id: item.id, item_tag_input: tag_names)}
  end

  def handle_event("cancel_item_form", _params, socket) do
    {:noreply, assign(socket, item_form: nil, editing_item_id: nil)}
  end

  def handle_event("save_item", %{"item" => params}, socket) do
    tags = parse_tags(params["tag_input"] || "")
    attrs = Map.merge(params, %{"box_id" => socket.assigns.box.id, "tags" => tags})

    result =
      if socket.assigns.editing_item_id do
        item = Inventory.get_item!(socket.assigns.editing_item_id)
        Inventory.update_item(item, attrs)
      else
        Inventory.create_item(attrs)
      end

    case result do
      {:ok, _item} ->
        box = Inventory.get_box!(socket.assigns.box.id)

        {:noreply,
         socket
         |> assign(box: box, item_form: nil, editing_item_id: nil)
         |> put_flash(:info, "Item saved.")}

      {:error, changeset} ->
        {:noreply, assign(socket, item_form: to_form(changeset))}
    end
  end

  def handle_event("delete_item", %{"id" => id}, socket) do
    item = Inventory.get_item!(id)

    case Inventory.delete_item(item) do
      {:ok, _} ->
        box = Inventory.get_box!(socket.assigns.box.id)
        {:noreply, socket |> assign(box: box) |> put_flash(:info, "Item deleted.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete item.")}
    end
  end

  def handle_event("depart_box", _params, socket) do
    case Inventory.depart_box(socket.assigns.box) do
      {:ok, box} ->
        {:noreply, socket |> assign(box: box) |> put_flash(:info, "Box marked as departed.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update box.")}
    end
  end

  def handle_event("arrive_box", _params, socket) do
    case Inventory.arrive_box(socket.assigns.box) do
      {:ok, box} ->
        {:noreply, socket |> assign(box: box) |> put_flash(:info, "Box marked as arrived.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update box.")}
    end
  end

  def handle_event("update_box", params, socket) do
    room_id = params["room_id"] || get_in(params, ["box", "room_id"])

    case Inventory.update_box(socket.assigns.box, %{"room_id" => room_id}) do
      {:ok, box} ->
        {:noreply,
         socket
         |> assign(box: box, page_title: "Box #{box.code}")
         |> put_flash(:info, "Box updated.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update box.")}
    end
  end

  def handle_event("seal_box", _params, socket) do
    case Inventory.seal_box(socket.assigns.box) do
      {:ok, box} ->
        {:noreply,
         socket
         |> assign(box: box, page_title: "Box #{box.code}")
         |> put_flash(:info, "Box sealed. Code #{box.code} is now fixed.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not seal box.")}
    end
  end

  def handle_event("unseal_box", _params, socket) do
    case Inventory.unseal_box(socket.assigns.box) do
      {:ok, box} ->
        {:noreply, socket |> assign(box: box) |> put_flash(:info, "Box unsealed.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not unseal box.")}
    end
  end

  defp parse_tags(input) when is_binary(input) do
    input
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp format_datetime(nil), do: ""
  defp format_datetime(%DateTime{} = dt), do: DateTime.to_string(dt)

  defp format_date(nil), do: "—"
  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y %H:%M")

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_page={@current_page}>
      <div class="space-y-6">
        <%!-- Header --%>
        <div class="flex items-start justify-between gap-4">
          <div>
            <div class="flex items-center gap-2">
              <.link navigate={~p"/boxes"} class="btn btn-ghost btn-sm btn-circle">
                <.icon name="hero-arrow-left" class="size-4" />
              </.link>
              <h1 class="text-2xl font-bold font-mono">{@box.code}</h1>
              <span :if={@box.fragile} class="badge badge-warning">
                <.icon name="hero-exclamation-triangle" class="size-3 mr-1" /> fragile
              </span>
            </div>
            <p class="text-base-content/60 ml-10">
              {@box.room.name}
            </p>
          </div>

          <div class="flex gap-2 flex-wrap justify-end">
            <form phx-change="update_box">
              <select class="select select-bordered select-sm" name="room_id">
                <option :for={{name, id} <- @rooms} value={id} selected={@box.room_id == id}>
                  {name}
                </option>
              </select>
            </form>
            <button
              :if={!@box.sealed && !@box.departed_at}
              class="btn btn-warning btn-sm"
              phx-click="seal_box"
            >
              <.icon name="hero-lock-closed" class="size-4" /> Seal
            </button>
            <button
              :if={@box.sealed && !@box.departed_at}
              class="btn btn-ghost btn-sm"
              phx-click="unseal_box"
            >
              <.icon name="hero-lock-open" class="size-4" /> Unseal
            </button>
            <button
              :if={@box.sealed && !@box.departed_at}
              class="btn btn-info btn-sm"
              phx-click="depart_box"
            >
              <.icon name="hero-truck" class="size-4" /> Mark Departed
            </button>
            <button
              :if={@box.departed_at && !@box.arrived_at}
              class="btn btn-success btn-sm"
              phx-click="arrive_box"
            >
              <.icon name="hero-check-circle" class="size-4" /> Mark Arrived
            </button>
          </div>
        </div>

        <%!-- Status timeline --%>
        <div class="flex items-center gap-2 text-sm flex-wrap">
          <div class={["badge", if(@box.sealed, do: "badge-warning", else: "badge-ghost")]}>
            <.icon
              name={if @box.sealed, do: "hero-lock-closed", else: "hero-lock-open"}
              class="size-3 mr-1"
            />
            {if @box.sealed, do: "Sealed", else: "Not sealed"}
          </div>
          <.icon name="hero-arrow-right" class="size-3 text-base-content/30" />
          <div class={["badge", if(@box.departed_at, do: "badge-info", else: "badge-ghost")]}>
            <.icon name="hero-truck" class="size-3 mr-1" />
            <span :if={@box.departed_at}>
              Departed
              <time title={format_datetime(@box.departed_at)} class="cursor-help">
                {format_date(@box.departed_at)}
              </time>
            </span>
            <span :if={!@box.departed_at}>Not departed</span>
          </div>
          <.icon name="hero-arrow-right" class="size-3 text-base-content/30" />
          <div class={["badge", if(@box.arrived_at, do: "badge-success", else: "badge-ghost")]}>
            <.icon name="hero-check-circle" class="size-3 mr-1" />
            <span :if={@box.arrived_at}>
              Arrived
              <time title={format_datetime(@box.arrived_at)} class="cursor-help">
                {format_date(@box.arrived_at)}
              </time>
            </span>
            <span :if={!@box.arrived_at}>Not arrived</span>
          </div>
        </div>

        <%!-- Items --%>
        <div class="card bg-base-200 shadow">
          <div class="card-body">
            <div class="flex items-center justify-between">
              <h2 class="card-title">
                Items <span class="badge badge-neutral badge-sm">{length(@box.items)}</span>
              </h2>
              <button
                :if={!@item_form}
                class="btn btn-sm btn-primary"
                phx-click="new_item"
              >
                <.icon name="hero-plus" class="size-4" /> Add Item
              </button>
            </div>

            <%!-- Add/edit item form --%>
            <div
              :if={@item_form}
              class="card bg-base-100 shadow-sm mt-2"
              data-form-open="true"
              data-cancel-event="cancel_item_form"
            >
              <div class="card-body py-3 px-4">
                <h3 class="font-medium text-sm">
                  {if @editing_item_id, do: "Edit Item", else: "New Item"}
                </h3>
                <.form for={@item_form} phx-submit="save_item" class="space-y-3">
                  <div class="form-control">
                    <input
                      type="text"
                      name={@item_form[:name].name}
                      value={@item_form[:name].value}
                      class="input input-bordered input-sm"
                      placeholder="Item name"
                      phx-mounted={JS.focus()}
                    />
                    <p :for={err <- @item_form[:name].errors} class="text-error text-xs mt-1">
                      {translate_error(err)}
                    </p>
                  </div>
                  <div class="form-control">
                    <input
                      type="text"
                      name="item[tag_input]"
                      value={Map.get(assigns, :item_tag_input, "")}
                      class="input input-bordered input-sm"
                      placeholder="Tags (comma-separated, e.g. kitchen, glassware)"
                    />
                    <p class="text-xs text-base-content/50 mt-1">
                      New tags are created automatically
                    </p>
                  </div>
                  <label class="label cursor-pointer gap-2 justify-start">
                    <input
                      type="checkbox"
                      name={@item_form[:fragile].name}
                      value="true"
                      checked={@item_form[:fragile].value}
                      class="checkbox checkbox-sm checkbox-warning"
                    />
                    <span class="label-text">Fragile</span>
                  </label>
                  <div class="flex gap-2">
                    <button type="submit" class="btn btn-primary btn-sm">Save</button>
                    <button
                      type="button"
                      class="btn btn-ghost btn-sm"
                      phx-click="cancel_item_form"
                    >
                      Cancel
                    </button>
                  </div>
                </.form>
              </div>
            </div>

            <%!-- Items list --%>
            <div class="overflow-x-auto mt-2">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Tags</th>
                    <th>Fragile</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={item <- @box.items} id={"item-#{item.id}"}>
                    <td>{item.name}</td>
                    <td>
                      <div class="flex flex-wrap gap-1">
                        <span
                          :for={tag <- item.tags}
                          class="badge badge-outline badge-sm"
                        >
                          {tag.name}
                        </span>
                      </div>
                    </td>
                    <td>
                      <span :if={item.fragile} class="badge badge-warning badge-sm">
                        fragile
                      </span>
                    </td>
                    <td>
                      <div class="flex gap-1 justify-end">
                        <button
                          class="btn btn-ghost btn-xs"
                          phx-click="edit_item"
                          phx-value-id={item.id}
                        >
                          <.icon name="hero-pencil" class="size-3" />
                        </button>
                        <button
                          class="btn btn-ghost btn-xs text-error"
                          phx-click="delete_item"
                          phx-value-id={item.id}
                          data-confirm={"Delete #{item.name}?"}
                        >
                          <.icon name="hero-trash" class="size-3" />
                        </button>
                      </div>
                    </td>
                  </tr>
                  <tr :if={@box.items == []}>
                    <td colspan="4" class="text-center text-base-content/50 py-6">
                      No items yet. Add some above.
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
