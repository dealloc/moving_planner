defmodule MovingPlannerWeb.TruckLive do
  use MovingPlannerWeb, :live_view

  alias MovingPlanner.Inventory
  alias MovingPlanner.Furniture
  alias MovingPlanner.Inventory.Box

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Inventory.subscribe()
      Furniture.subscribe()
    end

    {:ok,
     assign(socket,
       boxes: Inventory.list_boxes(),
       pieces: Furniture.list_pieces(),
       tab: :boxes,
       search: ""
     )}
  end

  def handle_info(:updated, socket) do
    {:noreply,
     assign(socket,
       boxes: Inventory.list_boxes(),
       pieces: Furniture.list_pieces()
     )}
  end

  def handle_params(_params, _uri, %{assigns: %{live_action: :depart}} = socket) do
    {:noreply, assign(socket, page_title: "Departing", current_page: :depart)}
  end

  def handle_params(_params, _uri, %{assigns: %{live_action: :arrive}} = socket) do
    {:noreply, assign(socket, page_title: "Arriving", current_page: :arrive)}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, tab: String.to_existing_atom(tab), search: "")}
  end

  def handle_event("search", %{"search" => term}, socket) do
    {:noreply, assign(socket, search: term)}
  end

  def handle_event("depart_box", %{"id" => id}, socket) do
    box = Inventory.get_box!(id)
    Inventory.depart_box(box)
    {:noreply, assign(socket, boxes: Inventory.list_boxes())}
  end

  def handle_event("arrive_box", %{"id" => id}, socket) do
    box = Inventory.get_box!(id)
    Inventory.arrive_box(box)
    {:noreply, assign(socket, boxes: Inventory.list_boxes())}
  end

  def handle_event("depart_piece", %{"id" => id}, socket) do
    piece = Furniture.get_piece!(id)
    Furniture.set_status(piece, :in_transit)
    {:noreply, assign(socket, pieces: Furniture.list_pieces())}
  end

  def handle_event("arrive_piece", %{"id" => id}, socket) do
    piece = Furniture.get_piece!(id)
    Furniture.set_status(piece, :arrived)
    {:noreply, assign(socket, pieces: Furniture.list_pieces())}
  end

  # ---------------------------------------------------------------------------
  # Sort helpers
  # ---------------------------------------------------------------------------

  defp sorted_boxes(boxes, :depart, search) do
    boxes
    |> filter_boxes(search)
    |> Enum.sort_by(fn b -> {if(b.departed_at, do: 1, else: 0), b.serial} end)
  end

  defp sorted_boxes(boxes, :arrive, search) do
    boxes
    |> filter_boxes(search)
    |> Enum.sort_by(fn b ->
      priority =
        cond do
          b.departed_at != nil and b.arrived_at == nil -> 0
          b.arrived_at != nil -> 1
          true -> 2
        end

      {priority, b.serial}
    end)
  end

  defp filter_boxes(boxes, ""), do: boxes

  defp filter_boxes(boxes, search) do
    term = String.downcase(search)
    Enum.filter(boxes, &String.contains?(String.downcase(&1.code || ""), term))
  end

  defp sorted_pieces(pieces, :depart, search) do
    pieces
    |> filter_pieces(search)
    |> Enum.sort_by(fn p ->
      done = p.status in [:in_transit, :arrived, :assembled]
      {if(done, do: 1, else: 0), p.name}
    end)
  end

  defp sorted_pieces(pieces, :arrive, search) do
    pieces
    |> filter_pieces(search)
    |> Enum.sort_by(fn p ->
      priority =
        cond do
          p.status == :in_transit -> 0
          p.status in [:arrived, :assembled] -> 1
          true -> 2
        end

      {priority, p.name}
    end)
  end

  defp filter_pieces(pieces, ""), do: pieces

  defp filter_pieces(pieces, search) do
    term = String.downcase(search)
    Enum.filter(pieces, &String.contains?(String.downcase(&1.name), term))
  end

  # ---------------------------------------------------------------------------
  # Per-item state helpers
  # ---------------------------------------------------------------------------

  defp box_done?(%Box{departed_at: d}, :depart), do: d != nil
  defp box_done?(%Box{arrived_at: a}, :arrive), do: a != nil

  defp box_inactive?(%Box{departed_at: nil}, :arrive), do: true
  defp box_inactive?(_, _), do: false

  defp box_action_label(:depart), do: "DEPART"
  defp box_action_label(:arrive), do: "ARRIVE"

  defp box_action_event(:depart), do: "depart_box"
  defp box_action_event(:arrive), do: "arrive_box"

  defp piece_done?(%{status: s}, :depart), do: s in [:in_transit, :arrived, :assembled]
  defp piece_done?(%{status: s}, :arrive), do: s in [:arrived, :assembled]

  defp piece_inactive?(%{status: s}, :arrive), do: s in [:pending, :disassembled]
  defp piece_inactive?(_, _), do: false

  defp piece_action_event(:depart), do: "depart_piece"
  defp piece_action_event(:arrive), do: "arrive_piece"

  defp piece_action_label(:depart), do: "DEPART"
  defp piece_action_label(:arrive), do: "ARRIVE"

  # ---------------------------------------------------------------------------
  # Tab counts
  # ---------------------------------------------------------------------------

  defp box_count(boxes, :depart) do
    done = Enum.count(boxes, & &1.departed_at)
    "#{done}/#{length(boxes)}"
  end

  defp box_count(boxes, :arrive) do
    done = Enum.count(boxes, & &1.arrived_at)
    "#{done}/#{length(boxes)}"
  end

  defp piece_count(pieces, :depart) do
    done = Enum.count(pieces, &(&1.status in [:in_transit, :arrived, :assembled]))
    "#{done}/#{length(pieces)}"
  end

  defp piece_count(pieces, :arrive) do
    done = Enum.count(pieces, &(&1.status in [:arrived, :assembled]))
    "#{done}/#{length(pieces)}"
  end

  defp status_badge_class(:pending), do: "badge-ghost"
  defp status_badge_class(:disassembled), do: "badge-warning"
  defp status_badge_class(:in_transit), do: "badge-info"
  defp status_badge_class(:arrived), do: "badge-success"
  defp status_badge_class(:assembled), do: "badge-primary"

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_page={@current_page}>
      <div class="space-y-4 max-w-lg mx-auto">
        <h1 class="text-2xl font-bold">
          {if @live_action == :depart, do: "🚚 Departing", else: "📦 Arriving"}
        </h1>

        <%!-- Search --%>
        <input
          type="text"
          class="input input-bordered w-full"
          placeholder="Search…"
          value={@search}
          phx-change="search"
          phx-debounce="300"
          name="search"
        />

        <%!-- Tabs --%>
        <div role="tablist" class="tabs tabs-bordered">
          <button
            role="tab"
            class={["tab", if(@tab == :boxes, do: "tab-active", else: "")]}
            phx-click="switch_tab"
            phx-value-tab="boxes"
          >
            📦 Boxes <span class="badge badge-sm ml-1">{box_count(@boxes, @live_action)}</span>
          </button>
          <button
            role="tab"
            class={["tab", if(@tab == :furniture, do: "tab-active", else: "")]}
            phx-click="switch_tab"
            phx-value-tab="furniture"
          >
            🪑 Furniture <span class="badge badge-sm ml-1">{piece_count(@pieces, @live_action)}</span>
          </button>
        </div>

        <%!-- Boxes list --%>
        <div :if={@tab == :boxes} class="space-y-2">
          <div
            :for={box <- sorted_boxes(@boxes, @live_action, @search)}
            id={"box-#{box.id}"}
            class={[
              "flex items-center gap-3 p-3 rounded-xl border-2",
              if(box_done?(box, @live_action),
                do: "border-success/30 bg-success/5 opacity-60",
                else:
                  if(box_inactive?(box, @live_action),
                    do: "border-base-300 opacity-40",
                    else: "border-base-300 bg-base-100"
                  )
              )
            ]}
          >
            <div class="w-12 h-12 rounded-xl bg-base-200 flex items-center justify-center text-2xl flex-shrink-0">
              📦
            </div>
            <div class="flex-1 min-w-0">
              <div class="font-bold font-mono">{box.code}</div>
              <div class="text-sm text-base-content/60">
                {box.room.name}
                <span :if={box.fragile} class="text-warning ml-1">· fragile</span>
              </div>
            </div>
            <div :if={box_done?(box, @live_action)} class="text-success font-bold text-lg">✓</div>
            <button
              :if={!box_done?(box, @live_action) && !box_inactive?(box, @live_action)}
              class="btn btn-primary btn-sm"
              phx-click={box_action_event(@live_action)}
              phx-value-id={box.id}
            >
              {box_action_label(@live_action)}
            </button>
          </div>
          <p
            :if={sorted_boxes(@boxes, @live_action, @search) == []}
            class="text-center text-base-content/50 py-8"
          >
            No boxes found.
          </p>
        </div>

        <%!-- Furniture list --%>
        <div :if={@tab == :furniture} class="space-y-2">
          <div
            :for={piece <- sorted_pieces(@pieces, @live_action, @search)}
            id={"piece-#{piece.id}"}
            class={[
              "flex items-center gap-3 p-3 rounded-xl border-2",
              if(piece_done?(piece, @live_action),
                do: "border-success/30 bg-success/5 opacity-60",
                else:
                  if(piece_inactive?(piece, @live_action),
                    do: "border-base-300 opacity-40",
                    else: "border-base-300 bg-base-100"
                  )
              )
            ]}
          >
            <div class="w-12 h-12 rounded-xl bg-base-200 flex items-center justify-center text-2xl flex-shrink-0">
              🪑
            </div>
            <div class="flex-1 min-w-0">
              <div class="font-bold">{piece.name}</div>
              <div class="text-sm text-base-content/60 flex items-center gap-1">
                {if piece.room, do: piece.room.name, else: "No room"}
                <span class={["badge badge-xs ml-1", status_badge_class(piece.status)]}>
                  {piece.status}
                </span>
              </div>
            </div>
            <div :if={piece_done?(piece, @live_action)} class="text-success font-bold text-lg">
              ✓
            </div>
            <button
              :if={!piece_done?(piece, @live_action) && !piece_inactive?(piece, @live_action)}
              class="btn btn-primary btn-sm"
              phx-click={piece_action_event(@live_action)}
              phx-value-id={piece.id}
            >
              {piece_action_label(@live_action)}
            </button>
          </div>
          <p
            :if={sorted_pieces(@pieces, @live_action, @search) == []}
            class="text-center text-base-content/50 py-8"
          >
            No furniture found.
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
