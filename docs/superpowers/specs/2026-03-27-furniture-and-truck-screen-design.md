# Furniture Tracking & Truck Loading Screen — Design Spec

**Date:** 2026-03-27
**Status:** Approved

---

## Overview

Two features added to the moving planner:

1. **Furniture tracking** — create furniture pieces and track them through a 5-state lifecycle
2. **Truck loading screen** — mobile-optimised departure and arrival screens for marking boxes and furniture on/off the truck

---

## Data Model

### New table: `furniture`

| Field | Type | Notes |
|---|---|---|
| `id` | integer | PK |
| `name` | string | required |
| `room_id` | FK → rooms | nullable — some pieces have no obvious room |
| `status` | Ecto.Enum | `pending \| disassembled \| in_transit \| arrived \| assembled`, default `:pending` |
| `notes` | string | nullable |
| `inserted_at` | utc_datetime | |
| `updated_at` | utc_datetime | |

No serial code needed — furniture is identified by name.

### Schema

`MovingPlanner.Furniture.Piece` in `lib/moving_planner/furniture/piece.ex`

- `changeset/2` casts `[:name, :room_id, :status, :notes]`, validates `name` required
- `statuses/0` returns the enum list (used by forms and tests)

### Context

`MovingPlanner.Furniture` in `lib/moving_planner/furniture.ex`

Functions:
- `list_pieces/0` — all pieces, preload room, order by name
- `get_piece!/1` — raises if not found
- `create_piece/1`
- `update_piece/2`
- `delete_piece/1`
- `change_piece/2`
- `cycle_status/1` — advances status: `pending → disassembled → in_transit → arrived → assembled → pending`
- `set_status/2` — sets status to a specific value (used by truck screen)

---

## Pages & Routes

| Route | LiveView | Live Action | Purpose |
|---|---|---|---|
| `/furniture` | `FurnitureLive.Index` | `:index` | List all pieces, tap badge to cycle status |
| `/furniture/new` | `FurnitureLive.Index` | `:new` | Create modal overlay |
| `/truck/depart` | `TruckLive` | `:depart` | Mark boxes/furniture as departed |
| `/truck/arrive` | `TruckLive` | `:arrive` | Mark boxes/furniture as arrived |

All routes added to the existing `:authenticated` `live_session` in the router.

### Sidebar navigation (flat, appended after existing items)

```
Dashboard
Boxes
Items
Rooms
Furniture        ← new (hero-table-cells icon)
Todos
──────────────
Depart           ← new (hero-truck icon)
Arrive           ← new (hero-check-circle icon)
──────────────
Import / Export
```

A visual divider separates the truck screens from inventory management since they are used in a different context (moving day).

---

## FurnitureLive.Index

### Behaviour

- Lists all pieces with name, room badge, status badge, notes snippet, and action buttons
- Status badge is tappable — triggers `cycle_status` event, updates in place
- "New Furniture" button opens a modal (same `:new` action pattern as BoxesLive)
- Create form: name (required), room dropdown (optional, includes all rooms), notes (optional textarea), status dropdown (defaults to pending)
- Delete button with confirmation

### Status badge colours

| Status | Badge style |
|---|---|
| pending | `badge-ghost` |
| disassembled | `badge-warning` |
| in_transit | `badge-info` |
| arrived | `badge-success` |
| assembled | `badge-primary` |

---

## TruckLive

### Shared layout (both modes)

- Header shows mode: "🚚 Departing" or "📦 Arriving"
- Search input (debounced 300ms) filters by box code or furniture name
- Two tabs: **Boxes** and **Furniture**, each with a `done/total` counter badge
- Big-tap rows (48px icon, large DEPART/ARRIVE button)
- On action: item updates immediately, then re-sorts — pending items float to top, done items sink to bottom within each tab
- No room grouping — flat list, sorted by status then name

### Depart mode (`/truck/depart`)

| Type | Button label | Action |
|---|---|---|
| Box (not yet departed) | DEPART | sets `departed_at = DateTime.utc_now()` |
| Box (already departed) | ✓ (green, no button) | — |
| Furniture (status < in_transit) | DEPART | sets status to `:in_transit` |
| Furniture (status ≥ in_transit) | ✓ (green, no button) | — |

DEPART is never blocked regardless of furniture status (not everything is disassemblable).

### Arrive mode (`/truck/arrive`)

| Type | Button label | Action |
|---|---|---|
| Box (departed, not arrived) | ARRIVE | sets `arrived_at = DateTime.utc_now()` |
| Box (already arrived) | ✓ (green, no button) | — |
| Box (not yet departed) | — (greyed out, skip) | shown but inactive |
| Furniture (in_transit) | ARRIVE | sets status to `:arrived` |
| Furniture (already arrived/assembled) | ✓ (green, no button) | — |
| Furniture (pending/disassembled) | — (greyed out, skip) | shown but inactive |

### Sort order within each tab

1. Pending / not-yet-actioned items — sorted by name
2. Done items (departed/arrived/in_transit/etc.) — sorted by name, visually dimmed

---

## Import / Export

`Data.export_json/0` and `Data.import_json/1` updated to include furniture:

- Export: furniture pieces serialised as `%{id, name, room_letter, status, notes}`
- Import: pieces re-inserted with original IDs; room resolved by letter (same pattern as boxes)
- Version field bumped to `2` — import still accepts `version: 1` data (no furniture section = skip furniture import, existing data untouched)

---

## What Is Not In Scope

- Furniture photos or dimensions
- Multiple truck runs (single-truck assumption)
- Assigning furniture to a destination room (only origin room tracked)
- Arrival screen showing only items that were marked departed (all items shown, inactive ones greyed out)
