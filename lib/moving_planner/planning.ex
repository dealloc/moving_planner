defmodule MovingPlanner.Planning do
  import Ecto.Query
  alias MovingPlanner.Repo
  alias MovingPlanner.Planning.Todo

  @next_status %{pending: :in_progress, in_progress: :done, done: :pending}
  @pubsub MovingPlanner.PubSub
  @topic "planning"

  def subscribe, do: Phoenix.PubSub.subscribe(@pubsub, @topic)

  def list_todos(opts \\ []) do
    Todo
    |> maybe_filter_status(Keyword.get(opts, :status))
    |> maybe_filter_overdue(Keyword.get(opts, :overdue))
    |> apply_order(Keyword.get(opts, :order_by, :inserted_at))
    |> Repo.all()
  end

  def get_todo!(id), do: Repo.get!(Todo, id)

  def create_todo(attrs) do
    %Todo{}
    |> Todo.changeset(attrs)
    |> Repo.insert()
    |> tap_broadcast()
  end

  def update_todo(%Todo{} = todo, attrs) do
    todo
    |> Todo.changeset(attrs)
    |> Repo.update()
    |> tap_broadcast()
  end

  def delete_todo(%Todo{} = todo), do: Repo.delete(todo) |> tap_broadcast()

  def change_todo(%Todo{} = todo \\ %Todo{}, attrs \\ %{}) do
    Todo.changeset(todo, attrs)
  end

  def cycle_status(%Todo{} = todo) do
    next = Map.fetch!(@next_status, todo.status)
    update_todo(todo, %{status: next})
  end

  defp maybe_filter_status(query, nil), do: query
  defp maybe_filter_status(query, :all), do: query

  defp maybe_filter_status(query, status) do
    where(query, [t], t.status == ^status)
  end

  defp maybe_filter_overdue(query, true) do
    today = Date.utc_today()
    where(query, [t], not is_nil(t.due_date) and t.due_date < ^today and t.status != :done)
  end

  defp maybe_filter_overdue(query, _), do: query

  defp apply_order(query, :due_date) do
    order_by(query, [t], asc_nulls_last: t.due_date, asc: t.inserted_at)
  end

  defp apply_order(query, _) do
    order_by(query, [t], asc: t.inserted_at)
  end

  defp tap_broadcast({:ok, _} = result) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, :updated)
    result
  end

  defp tap_broadcast(result), do: result
end
