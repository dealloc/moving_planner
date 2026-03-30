defmodule MovingPlannerWeb.TodosLive.Index do
  use MovingPlannerWeb, :live_view

  alias MovingPlanner.Planning
  alias MovingPlanner.Planning.Todo

  def mount(_params, _session, socket) do
    if connected?(socket), do: Planning.subscribe()

    {:ok,
     assign(socket,
       page_title: "Todos",
       current_page: :todos,
       todos: Planning.list_todos(order_by: :due_date),
       filter: :all,
       form: nil,
       editing_id: nil
     )}
  end

  def handle_info(:updated, socket) do
    {:noreply, assign(socket, todos: load_todos(socket.assigns.filter))}
  end

  def handle_event("filter", %{"status" => status}, socket) do
    filter = String.to_existing_atom(status)
    todos = load_todos(filter)
    {:noreply, assign(socket, filter: filter, todos: todos)}
  end

  def handle_event("new_todo", _params, socket) do
    {:noreply, assign(socket, form: to_form(Planning.change_todo()), editing_id: nil)}
  end

  def handle_event("edit_todo", %{"id" => id}, socket) do
    todo = Planning.get_todo!(id)
    {:noreply, assign(socket, form: to_form(Planning.change_todo(todo)), editing_id: todo.id)}
  end

  def handle_event("cancel_form", _params, socket) do
    {:noreply, assign(socket, form: nil, editing_id: nil)}
  end

  def handle_event("save_todo", %{"todo" => params}, socket) do
    result =
      if socket.assigns.editing_id do
        todo = Planning.get_todo!(socket.assigns.editing_id)
        Planning.update_todo(todo, params)
      else
        Planning.create_todo(params)
      end

    case result do
      {:ok, _todo} ->
        {:noreply,
         socket
         |> put_flash(:info, "Todo saved.")
         |> assign(form: nil, editing_id: nil, todos: load_todos(socket.assigns.filter))}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("cycle_status", %{"id" => id}, socket) do
    todo = Planning.get_todo!(id)

    case Planning.cycle_status(todo) do
      {:ok, _todo} ->
        {:noreply, assign(socket, todos: load_todos(socket.assigns.filter))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update status.")}
    end
  end

  def handle_event("delete_todo", %{"id" => id}, socket) do
    todo = Planning.get_todo!(id)

    case Planning.delete_todo(todo) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Todo deleted.")
         |> assign(todos: load_todos(socket.assigns.filter))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete todo.")}
    end
  end

  defp load_todos(:all), do: Planning.list_todos(order_by: :due_date)
  defp load_todos(status), do: Planning.list_todos(status: status, order_by: :due_date)

  defp status_badge_class(:pending), do: "badge-warning"
  defp status_badge_class(:in_progress), do: "badge-info"
  defp status_badge_class(:done), do: "badge-success"

  defp status_label(:pending), do: "pending"
  defp status_label(:in_progress), do: "in progress"
  defp status_label(:done), do: "done"

  defp overdue?(%Todo{due_date: nil}), do: false
  defp overdue?(%Todo{status: :done}), do: false

  defp overdue?(%Todo{due_date: due_date}) do
    Date.compare(due_date, Date.utc_today()) == :lt
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_page={@current_page}>
      <div class="space-y-4">
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold">Todos</h1>
          <button :if={!@form} class="btn btn-primary btn-sm" phx-click="new_todo">
            <.icon name="hero-plus" class="size-4" /> Add Todo
          </button>
        </div>

        <%!-- Status filter tabs --%>
        <div role="tablist" class="tabs tabs-bordered">
          <button
            :for={tab <- [:all, :pending, :in_progress, :done]}
            role="tab"
            class={["tab", if(@filter == tab, do: "tab-active", else: "")]}
            phx-click="filter"
            phx-value-status={tab}
          >
            {if tab == :all, do: "All", else: status_label(tab) |> String.capitalize()}
          </button>
        </div>

        <%!-- New todo form --%>
        <div
          :if={@form && !@editing_id}
          class="card bg-base-200 shadow"
          data-form-open="true"
          data-cancel-event="cancel_form"
        >
          <div class="card-body py-4">
            <.form for={@form} phx-submit="save_todo" class="space-y-3">
              <div class="flex gap-2 flex-wrap">
                <div class="form-control flex-1 min-w-48">
                  <input
                    type="text"
                    name={@form[:title].name}
                    value={@form[:title].value}
                    class="input input-bordered input-sm"
                    placeholder="Todo title"
                    autofocus
                  />
                  <p :for={err <- @form[:title].errors} class="text-error text-xs mt-1">
                    {translate_error(err)}
                  </p>
                </div>
                <div class="form-control w-36">
                  <input
                    type="date"
                    name={@form[:due_date].name}
                    value={@form[:due_date].value}
                    class="input input-bordered input-sm"
                  />
                </div>
              </div>
              <div class="form-control">
                <textarea
                  name={@form[:notes].name}
                  class="textarea textarea-bordered textarea-sm"
                  placeholder="Notes (optional)"
                  rows="2"
                >{@form[:notes].value}</textarea>
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

        <%!-- Todos list --%>
        <div class="space-y-2">
          <div :for={todo <- @todos} id={"todo-#{todo.id}"} class="card bg-base-200 shadow-sm">
            <div :if={@editing_id != todo.id} class="card-body py-3 px-4">
              <div class="flex items-start gap-3">
                <button
                  class={["badge cursor-pointer", status_badge_class(todo.status)]}
                  phx-click="cycle_status"
                  phx-value-id={todo.id}
                  title="Click to advance status"
                >
                  {status_label(todo.status)}
                </button>
                <div class="flex-1">
                  <p class={["font-medium", if(todo.status == :done, do: "line-through opacity-50")]}>
                    {todo.title}
                  </p>
                  <p :if={todo.notes} class="text-sm text-base-content/60 mt-0.5">{todo.notes}</p>
                </div>
                <div class="flex items-center gap-2 ml-auto">
                  <span
                    :if={todo.due_date}
                    class={[
                      "text-xs whitespace-nowrap",
                      if(overdue?(todo), do: "text-error font-medium", else: "text-base-content/50")
                    ]}
                  >
                    {Calendar.strftime(todo.due_date, "%b %d")}
                    {if overdue?(todo), do: "⚠"}
                  </span>
                  <button
                    class="btn btn-ghost btn-xs"
                    phx-click="edit_todo"
                    phx-value-id={todo.id}
                  >
                    <.icon name="hero-pencil" class="size-3" />
                  </button>
                  <button
                    class="btn btn-ghost btn-xs text-error"
                    phx-click="delete_todo"
                    phx-value-id={todo.id}
                    data-confirm="Delete this todo?"
                  >
                    <.icon name="hero-trash" class="size-3" />
                  </button>
                </div>
              </div>
            </div>
            <div
              :if={@editing_id == todo.id}
              class="card-body py-3 px-4"
              data-form-open="true"
              data-cancel-event="cancel_form"
            >
              <.form for={@form} phx-submit="save_todo" class="space-y-2">
                <div class="flex gap-2 flex-wrap">
                  <div class="form-control flex-1 min-w-48">
                    <input
                      type="text"
                      name={@form[:title].name}
                      value={@form[:title].value}
                      class="input input-bordered input-xs"
                      autofocus
                    />
                  </div>
                  <select name={@form[:status].name} class="select select-bordered select-xs w-36">
                    <option
                      :for={s <- Todo.statuses()}
                      value={s}
                      selected={to_string(@form[:status].value) == to_string(s)}
                    >
                      {status_label(s) |> String.capitalize()}
                    </option>
                  </select>
                  <input
                    type="date"
                    name={@form[:due_date].name}
                    value={@form[:due_date].value}
                    class="input input-bordered input-xs w-36"
                  />
                </div>
                <textarea
                  name={@form[:notes].name}
                  class="textarea textarea-bordered textarea-xs w-full"
                  rows="2"
                >{@form[:notes].value}</textarea>
                <div class="flex gap-2">
                  <button type="submit" class="btn btn-primary btn-xs">Save</button>
                  <button type="button" class="btn btn-ghost btn-xs" phx-click="cancel_form">
                    Cancel
                  </button>
                </div>
              </.form>
            </div>
          </div>

          <div :if={@todos == []} class="text-center text-base-content/50 py-12">
            No todos here.
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
