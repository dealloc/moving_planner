defmodule MovingPlanner.MCP.Tools.ListFurniture do
  @moduledoc """
  List furniture pieces and their move status.

  Returns each piece's name, room, current status, and any notes.
  Valid status values: pending, disassembled, in_transit, arrived, assembled.
  Leave status blank to list all furniture.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MovingPlanner.Furniture

  schema do
    field :status, :string,
      required: false,
      description: "Filter by status: pending, disassembled, in_transit, arrived, assembled"
  end

  @impl true
  def execute(params, frame) do
    pieces =
      Furniture.list_pieces()
      |> maybe_filter_status(Map.get(params, :status))

    text =
      if pieces == [] do
        "No furniture found."
      else
        lines =
          Enum.map(pieces, fn piece ->
            room = if piece.room, do: " · #{piece.room.name}", else: ""
            notes = if piece.notes && piece.notes != "", do: " (#{piece.notes})", else: ""
            "- #{piece.name}#{room} · #{piece.status}#{notes}"
          end)

        Enum.join(lines, "\n")
      end

    {:reply, Response.tool() |> Response.text(text), frame}
  end

  defp maybe_filter_status(pieces, nil), do: pieces
  defp maybe_filter_status(pieces, ""), do: pieces

  defp maybe_filter_status(pieces, status) do
    atom =
      case status do
        "pending" -> :pending
        "disassembled" -> :disassembled
        "in_transit" -> :in_transit
        "arrived" -> :arrived
        "assembled" -> :assembled
        _ -> nil
      end

    if atom, do: Enum.filter(pieces, &(&1.status == atom)), else: pieces
  end
end
