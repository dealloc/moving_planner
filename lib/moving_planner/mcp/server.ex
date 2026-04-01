defmodule MovingPlanner.MCP.Server do
  use Anubis.Server,
    name: "moving-planner",
    version: "1.0.0",
    capabilities: [:tools]

  alias Anubis.MCP.Error
  alias Anubis.Server.Handlers

  component(MovingPlanner.MCP.Tools.SearchItems)
  component(MovingPlanner.MCP.Tools.ListBoxes)
  component(MovingPlanner.MCP.Tools.GetBox)
  component(MovingPlanner.MCP.Tools.ListFurniture)
  component(MovingPlanner.MCP.Tools.GetStats)

  @impl true
  def init(_client_info, frame), do: {:ok, frame}

  @impl true
  def handle_request(request, frame) do
    Handlers.handle(request, __MODULE__, frame)
  rescue
    e ->
      message = Exception.message(e)
      {:error, Error.protocol(:internal_error, %{message: message}), frame}
  end
end
