# RD4 monitor world-feedback verification

Target: Factorio 2.0.77, base and Space Age; public Lua API v1 is unchanged.
This is an implementation/state evidence report, not graphical-client acceptance.
Native red-X visibility, selection/wire readability and pixel appearance remain
unverified until the user runs the short check below.

## Root trace and fix

RD1 makes the visible monitor constant-combinator shell the actual Network,
selection and deconstruction target. Its power carrier is private/nonselectable
and cannot be marked. The focused fixture orders/cancels deconstruction on the
real shell and reads `to_be_deconstructed('player')`; it never substitutes helper
flags for native body state.

Previously the panel/background/cursor used `draw_rectangle` (no general layer
property in the pinned API), while glyph sprites used `light-effect` (162), above
`entity-info-icon` (153). This was a credible occlusion path, not a graphical
reproduction. All display primitives now use supported `draw_sprite` layers:

| Component | Layer | Pinned numeric order |
| --- | --- | --- |
| Native body | object | 124 |
| Panel fill | higher-object-under | 126 |
| Cell background | higher-object-above | 127 |
| Glyph | train-stop-top | 128 |
| Blinking cursor | item-in-inserter-hand | 129 |
| Native wires | wires | 131 |
| Native info icons | entity-info-icon | 153 |
| Native selection | selection-box | 187 |

The existing compact device-status sprite stays on higher-object-above (127),
in the two-unit bezel. The display's ordered strata keep a changed background
below unchanged glyphs/cursor. These are world-content layers despite some of
the engine's historical layer names. No fake X, mark-time model mutation or
custom mark/cancel event is introduced. Native marking is independent of display
power and continuous updates; there is no tile suppression to reconcile.

An original MIT opaque 1×1 RGBA white sprite is generated as
`assets/glyphs/pixel.png`, inventoried in the provenance manifest and registered
as `tc-monitor-fill`. A fill's transformed opposite corners determine its center
and positive world extents; at sprite scale 1, one pixel is 1/32 tile, so runtime
scales are world width/height ×32. Glyph dimensions/rotation, cell pitch, cursor,
palette, group identities and touch transforms are unchanged.

Render graph `layer_version=2` distinguishes legacy retained rectangles/high-layer
glyphs. On admitted synchronized rendering, the old graph is retired through the
existing bounded cleanup and the model is redrawn on the new layers. No load
handler modifies storage or recreates draw objects. An unpowered old graph stays
hidden until restoration; cleanup/redraw can take bounded sweeps. The prior
60000 render reservation, 1024-cell/tick cap and shared scheduler limits are not
raised. Each fill still uses one object; no per-tile marker/extra overlay exists.

## Focused reproducible checks

Use fresh external directories and the exact same ZIP for every engine run:

    python3 assets/generate.py
    python3 assets/check.py --output /outside/repo/rd4-static
    python3 -m unittest discover -s tools -p test_build.py -v
    python3 tools/player_docs.py --check --report /outside/repo/rd4-player-docs.json
    python3 tools/build.py --output /outside/repo/rd4-artifact
    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive /outside/repo/rd4-artifact/tweaked-computers_0.1.1.zip \
      --output /outside/repo/rd4-feedback --fixture tests.monitor_feedback_engine \
      --data-fixture tests.monitor_feedback_data --production-context --cold
    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive /outside/repo/rd4-artifact/tweaked-computers_0.1.1.zip \
      --output /outside/repo/rd4-monitor --fixture tests.monitor_engine --cold

The dedicated feedback fixture runs in production storage/event ownership:

- Four genuine 2×2 arrays, all cardinal orientations; native marks on non-anchor
  subsets while other bodies remain unmarked; cancel does not rebuild objects,
  regroup, resize or change committed state.
- Real draw object type/layer readback, transformed fill centers/extents, glyph
  orientation and blinking cursor. These prove properties, not visible pixels.
- Live text/palette updates while marked; outage/restoration preserves the exact
  model/alias, cursor, colors, scale and grouping. Power state/energy transitions
  in this structural part are fixture-controlled, not graphical outage evidence.
- Non-anchor cardinal coordinate checks and production pending touch payloads
  with table-backed player/reach authorization. Headless creates no client player;
  this is explicitly not native input or client touch acceptance.
- Current and legacy draw graphs saved while real native marks remain pending;
  separate-process on_load checks unchanged model/render aliases and mark states
  before synchronized work, then legacy redraw/cleanup and cancellation.
- One actual construction robot mines one marked non-anchor monitor. Production
  removal fires exactly once, the storage chest receives exactly one logical
  monitor item, owned helpers and all retired panel/cursor/cell objects disappear,
  and three remaining tiles have valid split geometry. Only actual topology
  changes invoke normal buffer/dimension behavior.

The original monitor suite additionally checks all terminal methods, dirty and
mixed-revision sweeps, maximum 4704-cell grids, all byte glyph slots, existing
render reservation/refusal, channel authority, event behavior and cold mid-sweep
state/credit persistence. Its own player activation remains table-backed. Static
checks include all 147 image outputs, exact original/installed/generated hashes,
the one-pixel opaque fill, unchanged 64 socket coordinates, two-unit monitor bezel
and exact regeneration. Package tests check the actual gameplay archive bytes.

The handoff supplies archive SHA/path, per-case summaries, full engine logs and
cold shutdown results. A first static check correctly refused the old fixed
146-image inventory; the verifier now explicitly requires 147 and validates the
new fill independently. No failed run is represented as a pass.

## Short user-owned native check (still unperformed)

Use the exact candidate from the handoff on a backed-up test save, not a valuable
world. This intermediate development ZIP retains version 0.1.1 for verification;
it is not a replacement public 0.1.1 release. RD5 integrates; RD6 owns 0.1.2.

1. Make a powered 2×2 monitor, run the existing monitor example and continue
   writing text/changing backgrounds with cursor blink enabled. At normal zoom,
   mark just one non-anchor tile: confirm the genuine native red X stays legible
   while content changes, other tiles have no X, and hover/red-green wires remain
   legible. Repeat with a dark/unpowered array and another orientation.
2. Save/load while marked, cancel before a robot arrives, restore power and check
   the same content/cursor/palette/group remain without a resize or reset. Ctrl +
   click a non-anchor character and confirm its combined-screen coordinates.
3. Mark again with robots available: confirm normal native removal/splitting and
   no floating display fragments or extra item/helper drops.

Report any obscured/missing X with the candidate hash, orientation, power state
and screenshot. Headless success must not be used to close this visual check.
