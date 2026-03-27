defmodule MovingPlannerWeb.DashboardLive do
  use MovingPlannerWeb, :live_view

  alias MovingPlanner.Inventory
  alias MovingPlanner.Planning

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Inventory.subscribe()
      Planning.subscribe()
    end

    stats = Inventory.box_stats()
    todos = Planning.list_todos(status: :in_progress, order_by: :due_date)

    {:ok,
     assign(socket,
       page_title: "Dashboard",
       current_page: :dashboard,
       stats: stats,
       todos: todos
     )}
  end

  def handle_info(:updated, socket) do
    {:noreply,
     assign(socket,
       stats: Inventory.box_stats(),
       todos: Planning.list_todos(status: :in_progress, order_by: :due_date)
     )}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_page={@current_page}>
      <div class="space-y-6">
        <h1 class="text-2xl font-bold">Dashboard</h1>

        <%!-- Stats --%>
        <div class="stats stats-vertical sm:stats-horizontal shadow w-full">
          <div class="stat">
            <div class="stat-figure text-primary">
              <.icon name="hero-archive-box" class="size-8" />
            </div>
            <div class="stat-title">Total Boxes</div>
            <div class="stat-value">{@stats.total}</div>
          </div>

          <div class="stat">
            <div class="stat-figure text-info">
              <.icon name="hero-truck" class="size-8" />
            </div>
            <div class="stat-title">Departed</div>
            <div class="stat-value text-info">{@stats.departed}</div>
          </div>

          <div class="stat">
            <div class="stat-figure text-success">
              <.icon name="hero-check-circle" class="size-8" />
            </div>
            <div class="stat-title">Arrived</div>
            <div class="stat-value text-success">{@stats.arrived}</div>
          </div>

          <div class="stat">
            <div class="stat-figure text-warning">
              <.icon name="hero-exclamation-triangle" class="size-8" />
            </div>
            <div class="stat-title">Fragile</div>
            <div class="stat-value text-warning">{@stats.fragile}</div>
          </div>
        </div>

        <%!-- Progress --%>
        <div :if={@stats.total > 0} class="card bg-base-200 shadow">
          <div class="card-body">
            <h2 class="card-title text-base">Move Progress</h2>
            <div class="flex items-center gap-3">
              <progress
                class="progress progress-success flex-1"
                value={@stats.arrived}
                max={@stats.total}
              >
              </progress>
              <span class="text-sm font-medium whitespace-nowrap">
                {@stats.arrived}/{@stats.total} arrived
              </span>
            </div>
          </div>
        </div>

        <%!-- In-progress todos --%>
        <div :if={@todos != []} class="card bg-base-200 shadow">
          <div class="card-body">
            <h2 class="card-title text-base">In Progress</h2>
            <ul class="space-y-2">
              <li :for={todo <- @todos} class="flex items-center gap-2">
                <span class="badge badge-info badge-sm">in progress</span>
                <span class="text-sm">{todo.title}</span>
                <span
                  :if={todo.due_date}
                  class={[
                    "text-xs ml-auto",
                    if(Date.compare(todo.due_date, Date.utc_today()) == :lt,
                      do: "text-error",
                      else: "text-base-content/50"
                    )
                  ]}
                >
                  {Calendar.strftime(todo.due_date, "%b %d")}
                </span>
              </li>
            </ul>
            <div class="card-actions">
              <.link navigate={~p"/todos"} class="btn btn-sm btn-ghost">
                View all todos <.icon name="hero-arrow-right" class="size-4" />
              </.link>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
