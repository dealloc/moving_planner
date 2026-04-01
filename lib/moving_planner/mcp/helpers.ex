defmodule MovingPlanner.MCP.Helpers do
  @moduledoc false

  def box_status(%{arrived_at: a}) when not is_nil(a), do: "arrived"
  def box_status(%{departed_at: d}) when not is_nil(d), do: "in transit"
  def box_status(%{sealed: true}), do: "sealed, not yet departed"
  def box_status(_), do: "packing (not sealed)"
end
