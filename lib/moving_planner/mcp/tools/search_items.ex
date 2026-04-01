defmodule MovingPlanner.MCP.Tools.SearchItems do
  @moduledoc """
  Search for items by name or tag across all boxes.

  Returns which box each item is in, whether the box has departed, and the room it belongs to.
  Use this to answer questions like "where is my toothbrush?" or "which box has the kitchen knives?".
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MovingPlanner.Inventory
  alias MovingPlanner.MCP.Helpers

  schema do
    field :query, :string,
      required: true,
      description: "Search term to match against item names and tags"
  end

  @impl true
  def execute(%{query: query}, frame) do
    items = Inventory.list_items(search: query)

    text =
      if items == [] do
        "No items found matching \"#{query}\"."
      else
        lines =
          Enum.map(items, fn item ->
            tags = item.tags |> Enum.map(& &1.name) |> Enum.join(", ")
            tag_part = if tags != "", do: " [#{tags}]", else: ""
            status = Helpers.box_status(item.box)
            fragile = if item.fragile, do: " ⚠ fragile", else: ""

            "- #{item.name}#{tag_part}#{fragile} → Box #{item.box.code} · #{item.box.room.name} · #{status}"
          end)

        Enum.join(lines, "\n")
      end

    {:reply, Response.tool() |> Response.text(text), frame}
  end
end
