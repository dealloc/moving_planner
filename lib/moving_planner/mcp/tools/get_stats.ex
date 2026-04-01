defmodule MovingPlanner.MCP.Tools.GetStats do
  @moduledoc """
  Get overall move progress statistics.

  Returns counts of boxes by status (total, departed, arrived, in transit, fragile)
  along with a percentage progress indicator.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MovingPlanner.Inventory

  schema do
  end

  @impl true
  def execute(_params, frame) do
    stats = Inventory.box_stats()

    pct =
      if stats.total > 0 do
        Float.round(stats.arrived / stats.total * 100, 1)
      else
        0.0
      end

    text =
      """
      Move Progress: #{stats.arrived}/#{stats.total} boxes arrived (#{pct}%)

      Boxes:
        Total:      #{stats.total}
        In transit: #{stats.in_transit}
        Arrived:    #{stats.arrived}
        Fragile:    #{stats.fragile}
      """
      |> String.trim_trailing()

    {:reply, Response.tool() |> Response.text(text), frame}
  end
end
