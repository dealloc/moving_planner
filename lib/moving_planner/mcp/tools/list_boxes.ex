defmodule MovingPlanner.MCP.Tools.ListBoxes do
  @moduledoc """
  List boxes, optionally filtered by status.

  Returns box codes, rooms, item counts, and current status.
  Valid status values: all, packing, sealed, in_transit, arrived.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MovingPlanner.Inventory
  alias MovingPlanner.MCP.Helpers

  schema do
    field :status, :string,
      required: false,
      description: "Filter by status: all, packing, sealed, in_transit, arrived"
  end

  @impl true
  def execute(params, frame) do
    opts = build_opts(Map.get(params, :status))
    boxes = Inventory.list_boxes(opts)

    text =
      if boxes == [] do
        "No boxes found."
      else
        lines =
          Enum.map(boxes, fn box ->
            fragile = if box.fragile, do: " ⚠", else: ""
            item_count = length(box.items)
            status = Helpers.box_status(box)
            "#{box.code} · #{box.room.name}#{fragile} · #{item_count} item(s) · #{status}"
          end)

        Enum.join(lines, "\n")
      end

    {:reply, Response.tool() |> Response.text(text), frame}
  end

  defp build_opts(nil), do: []
  defp build_opts("all"), do: []
  defp build_opts("packing"), do: [status: :not_departed]
  defp build_opts("sealed"), do: [sealed: true]
  defp build_opts("in_transit"), do: [status: :in_transit]
  defp build_opts("arrived"), do: [status: :arrived]
  defp build_opts(_), do: []
end
