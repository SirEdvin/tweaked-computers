# Design

## Context

- Monitor methods are dispatched through `model.calls` in `scripts/services/monitor.lua`. Mutating calls mark presentation participation. `setTextScale` and settings paste queue `monitor_resize`.
- Terminal presentation is buffered: snapshot, prepare, then an atomic commit (see `monitor-row-text-presentation`). Graphics content does not need this pipeline. Factorio draws only between ticks, so every native change made in one tick appears in one frame.
- Monitor settings for paste, blueprints and item tags are versioned records in `scripts/lifecycle-data.lua` (version 1: scale, fg, bg, blink, palette).
- `render_object_limit` (203,872) is published in `TC.MonitorLimits`, but today nothing enforces it at runtime. Terminal objects are bounded only indirectly, through cell caps.
- Pinned 2.1.23 facts:
  - `rendering.draw_line`, `draw_polygon` (triangle strip, `vertices` writable), `draw_rectangle`, `draw_circle`, `draw_arc`, `draw_text`, `draw_sprite` and `draw_light` all return `LuaRenderObject`s with writable properties.
  - `bring_to_front` and `move_to_back` exist.
  - Line widths are in screen pixels at 32 per tile.
  - Only sprites and animations have `render_layer`.
  - There is no runtime size for sprite paths or animation prototypes.
  - `helpers.is_valid_sprite_path` validates paths.
  - Native draws measured 0.08 ms per 62-point frame (spike).

## Goals / Non-Goals

**Goals:**
- Give a thin and cheap passthrough: one guest call becomes one validated native create or property write.
- Make exact, host-checked bounds the only containment mechanism.
- Make graphics state as durable as terminal state.

**Non-Goals:**
- No animations, arbitrary sprites, other fonts, rich text, clipping or batched calls. These are excluded or deferred by the proposal decisions.
- No change to terminal presentation or to the sandbox call overhead.

## Decisions

### D1. Separate graphics store per logical display
`scripts/monitor-graphics.lua` owns `g.graphics = {next_id, order = {ids...}, objects = {[id] = {type, props, native}}}`. The terminal model (`g.model`) is kept and holds `mode`.
- The terminal model is not reset to free memory in graphics mode. Its cursor, colours, palette and scale persist for a return to terminal mode, as the API states.
- `order` is a dense array. `bringToFront` and `moveToBack` cost O(n) array moves, charged as work per moved entry.

Alternative: keep only native objects and read properties back from `LuaRenderObject`. Rejected: native readback returns world coordinates and engine units. `get` must return pixel properties, so the stored props are the source of truth, and the native object is a projection of them.

### D2. Pixel → world projection
- A pixel point `(x, y)` maps to local tile coordinates `((2+x)/64, (2+y)/64)`, then to world coordinates through the existing `model.world(g, u, v)`, which already handles the four directions.
- Line, outline and circle widths: `width_native = width_px / 2`, because Factorio uses 32 px per tile and monitors 64.
- Radii and lengths are divided by 64.
- Text and sprite orientation is `props.orientation + direction/16`.
- Text uses the font, scale and offset compensation chosen in the row-text gate.
- Rectangles keep `left_top` and `right_bottom` in local axes. On rotated displays they are emitted as the corresponding world corner pair (min and max after rotation), because Factorio rectangles are axis-aligned and a cardinal rotation keeps them axis-aligned.

### D3. Exact bounds
One function computes the covered local box for every type, from the complete object after defaults or a partial `set`:
- line: both end points ± width/2;
- rectangle: the corners, ± width/2 when outlined;
- circle: target ± radius (+ width/2 when outlined);
- arc: the annulus-sector box, from the end points of both radii plus each axis extreme inside the sweep;
- polygon: the vertex extrema;
- text and sprite: their rectangle, placed by its anchor and rotated, with the box of the four corners;
- light: target ± radius.

The box must lie within `[0, W] × [0, H]`. Floating-point comparisons use an epsilon of 1e-9 px, so exact fits (spec scenario) pass. This function is pure Lua and gets a table-driven contract test per type, including the scenarios of the spec.

### D4. Sizes that need calibration
Two native sizes are measured once in the pinned client and recorded as constants with their evidence:
- icon sprites: the native scale for a 64-px icon box;
- the default light texture (`utility/light_medium`): the scale for which its glow is visibly contained in the radius.

The API is defined by those pixel results ("scale 1 = 64×64 px", "radius"), not by engine scale numbers. A later engine change therefore needs only a recalibration.

### D5. Layer and order
Sprites and lights get the render layer that the calibration gate (task 1.2) shows to sit together with shapes and text, above the panel and below native feedback.
- Draw order follows creation and `bring_to_front`/`move_to_back`, mirrored in `order`.
- If the gate shows that no sprite layer interleaves with shape objects, the spec's cross-type order cannot hold. The change then stops for a design decision; it does not silently weaken the requirement.
- The same gate checks native feedback above shapes. If shapes draw above the deconstruction marker, the fallback is presentation-only suppression: while any member tile is marked, the display's objects are set `visible=false` and restored on cancel. The spec allows this, and ids are unchanged.

### D6. Capacity
`s.native_objects` counts every native object that monitors own: terminal fronts, rows, backgrounds, panels, cursors, and graphics objects.
- The row presenter updates the count when it creates or destroys objects.
- Graphics draw calls check `count + 1 <= render_object_limit` before the native call, and fail with `E_CAPACITY` when the check fails.
- Terminal presentation that would exceed the limit defers its commit through the existing capacity path.
- Upgrade initialization computes the count from the retained objects.

This makes the published limit enforced, without adding a new limit.

### D7. Work charges
Each method charges `spend(1)` for dispatch, as other monitor methods do. It then charges per argument entry and byte through the existing peripheral data copy, plus a fixed native-call charge (16) and the order-move cost.

`get` and `getObjects` charge the size of their copies. Entry and byte allowances (`peripheral_call_entries`, `peripheral_call_bytes`) bound polygon size and text. No new allowance is added.

### D8. Mode switch and sync groups
`setMode` (and settings transfer) does the following:
1. It validates the mode.
2. If the mode is unchanged, it marks participation and returns.
3. It clears both stores: terminal cells are blanked with damage marked; graphics objects are destroyed and counted.
4. It sets `model.mode`.
5. It calls `presentation.changed(g)` so the terminal front retires or rebuilds.
6. For graphics, it calls `presentation.leave_group(g)`, which removes this member from any lane and keeps the others.
7. It queues `monitor_resize` with reason `mode`.

`presentation.select` refuses graphics members with `E_UNSUPPORTED` before any replacement. While in graphics mode the presenter treats the display as having an empty front: its panel stays and no rows are drawn.

### D9. Touch, resize and inspector
- `model.touch` returns pixels in graphics mode: `floor((u - 2/64) * 64)` within `[0, W)`, with the bezel excluded.
- The touch and resize payloads gain `mode`.
- In graphics mode, tile geometry reconciliation destroys the objects and queues the resize with pixel sizes.
- The inspector model adds the mode, the pixel size and `#order`.

### D10. Persistence and upgrade
- Graphics stores and native objects are saved by the engine. On load, the stored objects are validated with the existing shape validator; an invalid store fails closed.
- Monitor settings become version 2 with `mode`. Version 1 imports as terminal.
- Models without `mode` are terminal, so the existing saves need no migration pass.

### API review
The declarations in `api/monitor.d.lua`, `api/events.d.lua` and `api/peripheral.d.lua` are full replacements. They are promoted to canonical `api/` during apply, and both references are regenerated. No public identity is removed. Behavioral deltas are in `specs/monitor-graphics` and `specs/monitor-display`.

## Risks / Trade-offs

- [The engine may not interleave sprite layers with shape objects] → Gate D5 runs before implementation of order. A failed gate stops the change for a decision.
- [Shapes above the deconstruction marker] → Presentation-only suppression fallback (D5).
- [Icon or light calibration differs between base and Space Age, or between graphics quality settings] → Measure all four combinations (base/SA × normal/low). Refuse to ship one constant if they differ, and report the difference.
- [Guests keep thousands of objects and use `getObjects()` every callback] → It is charged per entry. Documentation recommends keeping ids in state.
- [Factorio rectangle outline and line caps extend past ±width/2] → The calibration capture checks the visible stroke against the bounds at width 1, 2 and 8. The bounds formula is widened only if pixels are found outside.
- [Text offset from the row-text gate] → Graphics text reuses the compensation chosen there and is checked again in this change's capture.

## Migration Plan

No migration pass is needed: a missing `mode` means terminal. Settings version 2 is read by this release only. An older release refuses those settings records as unsupported, as earlier settings versions did.
