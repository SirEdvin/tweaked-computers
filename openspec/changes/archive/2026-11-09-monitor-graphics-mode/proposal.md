## Why

A monitor can only draw a character grid. A chart or gauge has to be encoded as mosaic glyphs, sent with one `blit` call per row, then turned back into native objects by the host. A measured stand-in for a vector call on one 6×6 wall cut whole-scheduler time from 1.97 to 1.36 ms/tick. One native polygon update costs about 0.08 ms per frame at 62 points and 0.36 ms at 252 points. Per-cell sprites cost 8.4 ms per frame at 126×84. Evidence: `/home/siredvin/artifacts/tweaked-computers/vector-api-estimate-2026-11-09/` and `row-text-spike-2026-11-09/`.

Factorio's own rendering API already provides retained lines, polygons, rectangles, circles, arcs, text, sprites and lights. Exposing that model inside the monitor's area gives programs cheap native graphics, with no host translation per cell.

## What Changes

- A monitor has a mode: `terminal` (default, the current API) or `graphics`. `m.setMode(mode)` switches it, and `m.getMode()` reads it. A real switch clears the screen and queues `monitor_resize` with reason `mode`.
- In graphics mode, retained-object methods mirror `LuaRendering`:
  - `drawLine`, `drawPolygon`, `drawRectangle`, `drawCircle`, `drawArc`, `drawText`, `drawSprite` and `drawLight` return an integer object id;
  - `set(id, props)`, `get(id)`, `getObjects()`, `destroy(id)`, `bringToFront(id)`, `moveToBack(id)` and `clear()` manage the objects.
- Coordinates are monitor pixels, 64 per tile. The origin is the top-left of the content area inside the bezel; x points right and y points down. All units follow the display's orientation.
- An object whose bounding box leaves the content area is refused with `E_RANGE`. There is no clipping and no clamping.
- Text uses only the mod terminal font from `monitor-row-text-presentation`, without rich text, so its size is exact. Sprites accept game icon paths only (`item/`, `fluid/`, `entity/`, `virtual-signal/` and similar). Lights use only the engine's default light texture, sized by a pixel radius. Animations are not included.
- Colours are Factorio colour tables with channels 0..1; alpha defaults to 1.
- Graphics changes are applied at call time and appear together at the end of the tick. Graphics-mode monitors cannot join monitor sync groups. Switching a member to graphics removes it from its group.
- In graphics mode, terminal methods raise `E_UNSUPPORTED`. `getSize` returns content pixels, and `monitor_touch` and `monitor_resize` report pixels. Graphics methods raise `E_UNSUPPORTED` in terminal mode.
- Graphics objects count against the existing aggregate `render_object_limit`. No new limit is added.
- The mode persists like text scale (save/load, merge/split inheritance, settings paste). The inspector shows the mode, the pixel size and the object count.

## Capabilities

### New Capabilities

- `monitor-graphics`: graphics mode on monitors. It covers mode switching, retained native objects, coordinates, bounds, primitive restrictions, ordering, ids, persistence and capacity.

### Modified Capabilities

- `monitor-display`: terminal methods, character-cell touch, resize semantics and synchronized groups depend on the monitor mode.

## Impact

- Code: `scripts/monitor-model.lua` (mode, pixel size), new `scripts/monitor-graphics.lua` (object store, bounds, native calls), `scripts/services/monitor.lua` (method table, touch, resize, availability), `scripts/monitor-presentation.lua` (sync-group exclusion, removal of terminal fronts on a mode switch), inspector UI, settings paste and blueprint tags.
- Depends on `monitor-row-text-presentation` for the terminal font and its offset gate.
- Tests: new graphics contract and engine fixtures; touch/resize fixtures for both modes; sync-group refusal; cold reload; upgrade of saves without a mode.
- Docs: `docs/monitor.md`, a player guide page with a graphics example, `examples/` graphics chart.

## API Impact

Status: changed
Reason: New monitor methods, a mode-dependent `getSize`, touch and resize payloads, and a new sync-group refusal.
Compatibility: Existing programs see no change in terminal mode, which is the default for new and upgraded monitors. Event handlers that assume cell units continue to work for terminal-mode monitors; `mode` fields distinguish graphics payloads. No public identity is removed.

| Canonical path | Disposition | Removed identities |
| --- | --- | --- |
| api/monitor.d.lua | modified | - |
| api/events.d.lua | modified | - |
| api/peripheral.d.lua | modified | - |
