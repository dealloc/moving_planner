defmodule MovingPlanner.MCP.Server do
  use Anubis.Server,
    name: "moving-planner",
    version: "1.0.0",
    capabilities: [:tools]

  component(MovingPlanner.MCP.Tools.SearchItems)
  component(MovingPlanner.MCP.Tools.ListBoxes)
  component(MovingPlanner.MCP.Tools.GetBox)
  component(MovingPlanner.MCP.Tools.ListFurniture)
  component(MovingPlanner.MCP.Tools.GetStats)

  @impl true
  def init(_client_info, frame), do: {:ok, frame}
end
