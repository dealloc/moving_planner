defmodule MovingPlanner.MCP.Tools.GetBox do
  @moduledoc """
  Get the full contents of a specific box by its code.

  Returns all items in the box along with their tags and fragile status.
  Example code format: "B-L-001" or "B-BAT-002".
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MovingPlanner.Inventory
  alias MovingPlanner.Inventory.Box
  alias MovingPlanner.MCP.Helpers

  schema do
    field :code, :string, required: true, description: "Box code, e.g. \"B-L-001\""
  end

  @impl true
  def execute(%{code: code}, frame) do
    text =
      case Box.parse_code(code) do
        {:ok, _letter, serial} ->
          case Inventory.get_box_by_serial(serial) do
            nil ->
              "Box with code \"#{code}\" not found."

            box ->
              format_box(box)
          end

        :error ->
          "Invalid box code format: \"#{code}\". Expected format like \"B-L-001\"."
      end

    {:reply, Response.tool() |> Response.text(text), frame}
  end

  defp format_box(box) do
    status = Helpers.box_status(box)
    fragile = if box.fragile, do: " ⚠ fragile", else: ""
    header = "Box #{box.code} · #{box.room.name}#{fragile} · #{status}"

    item_lines =
      if box.items == [] do
        ["  (no items)"]
      else
        Enum.map(box.items, fn item ->
          tags = item.tags |> Enum.map(& &1.name) |> Enum.join(", ")
          tag_part = if tags != "", do: " [#{tags}]", else: ""
          frag = if item.fragile, do: " ⚠", else: ""
          "  - #{item.name}#{tag_part}#{frag}"
        end)
      end

    ([header] ++ item_lines) |> Enum.join("\n")
  end
end
