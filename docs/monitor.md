# In-world color monitors (API v1)

Place `tc-monitor` tiles with the same force, surface and cardinal orientation
next to each other. A complete rectangle shares one display. Holes, L-shapes
and arrays exceeding 6×6 partition deterministically. The algorithm starts with the smallest world `(y,x,id)`
unassigned tile. It selects the largest complete anchored rectangle. For equal areas, it prefers
world width, then height. Every tile belongs to one rectangle.

Wire a computer's NETWORK port to any member's NETWORK port with red or green.
Use the explicit color in `peripheral.find('monitor','red')` or
`peripheral.wrap(name,'red')`. Geometric grouping never connects unwired member
ports. A red path cannot leave another member's green wire, or cross between
unwired members. Discovery still traverses actual mod-owned wires only.

## Calling the terminal

All methods use dot syntax. Extra arguments, combined color masks and implicit
number/string coercion are rejected. Ordinary failures are catchable ApiError
values (`E_ARGUMENT`, `E_RANGE`, `E_LIMIT`, `E_UNREACHABLE`,
`E_NETWORK_PENDING`). Rejected calls leave the model unchanged. Shared callback
budget exhaustion is fatal, not a recoverable yield. Earlier accepted effects
remain committed.

| Method | Result / behavior |
| --- | --- |
| `write(text)` | No returns. One byte per cell. Clips, never wraps. X advances by the full byte length. |
| `blit(text,fg,bg)` | No returns. Equal byte lengths. Color strings contain lowercase `0`–`f`. All validation precedes mutation. |
| `clear()` / `clearLine()` | No returns. Fills the complete grid/current visible row with spaces/current colors. The cursor stays unchanged. |
| `scroll(lines)` | No returns. Safe integer. Positive moves upwards, negative downwards. Exposed rows use current colors. Large offsets clear without offset-sized loops. |
| `getSize()` | Columns, rows. |
| `getCursorPos()` / `setCursorPos(x,y)` | Two safe integers / no returns. Offscreen positions allowed, writes clipped. Final X must remain safe. |
| `getCursorBlink()` / `setCursorBlink(bool)` | Boolean / no returns. Offscreen blink remains stored. |
| `getTextColor()` / `setTextColor(color)` | Foreground mask / no returns. |
| `getBackgroundColor()` / `setBackgroundColor(color)` | Background mask / no returns. |
| `isColor()` | `true`. |
| `setPaletteColor(color,rgb)` | No returns. Packed integer RGB 0–16777215. |
| `setPaletteColor(color,r,g,b)` | No returns. Exactly three finite channels 0–1. |
| `getPaletteColor(color)` | r, g, b. |
| `getTextScale()` / `setTextScale(scale)` | Number / no returns. Half-steps 0.5 through 5. Initial 1. |
| `getLimits()` | Defensive capability/common-call ceilings snapshot. Works without display power, but still requires live discovery authority. |

Every Color spelling also has an identical Colour alias, including `isColour`.
`colors` and `colours` are the same immutable namespace. Blit digits index these
masks/default RGB values (one mask only, never a combined mask):

| Digit | Constant | Mask | RGB |
| --- | --- | --- | --- |
| 0 | white | 1 | F0F0F0 |
| 1 | orange | 2 | F2B233 |
| 2 | magenta | 4 | E57FD8 |
| 3 | lightBlue | 8 | 99B2F2 |
| 4 | yellow | 16 | DEDE6C |
| 5 | lime | 32 | 7FCC19 |
| 6 | pink | 64 | F2B2CC |
| 7 | gray / grey | 128 | 4C4C4C |
| 8 | lightGray / lightGrey | 256 | 999999 |
| 9 | cyan | 512 | 4C99B2 |
| a | purple | 1024 | B266E5 |
| b | blue | 2048 | 3366CC |
| c | brown | 4096 | 7F664C |
| d | green | 8192 | 57A64E |
| e | red | 16384 | CC4C4C |
| f | black | 32768 | 111111 |

The initial cursor is (1,1), blink is false, text is white and the background is black. Palette edits
recolor existing cells. Palette entries are not copied into stored cell colors.
No rich text, newline/tab/escape execution or UTF-8 decoding occurs. Slots 32–126
are independent 6×9 ASCII glyphs. Slots 128–159 are 2×3 mosaics. Bits 0–4 select
the first five 3×3 foreground subcells. The bottom-right subcell is always background. Other
bytes use an outlined replacement box. See `assets/README.md` for provenance.

## Geometry, identity and power

A tile is 64 logical units. The complete rectangle has a two-unit bezel per edge.
Center the grid inside it. Columns = max(1,floor((64*W-4)/(6*scale))), rows =
max(1,floor((64*H-4)/(9*scale))). W/H follow local display right/down, rotated
clockwise with north/east/south/west. Rendering and touch use the same transform.
A 1×1 at scale 1 has 10×6 cells. A 6×6 at 0.5 has 126×84 = 10584 cells.

The surviving anchor keeps its opaque logical identity. When multiple retained
anchors merge, the smallest stable anchor ID wins. Split rectangles without a
surviving anchor receive fresh names and inherit predecessor settings. Removing
an anchor never retargets its old name. Changed character dimensions clear the
complete resulting buffer in retained current colors. Cursor/blink are never
clamped. Same dimensions preserve cells. New independent displays use defaults.
Bounded pending regrouping explicitly refuses discovery with E_NETWORK_PENDING.
Retry on a later callback/tick, not in a busy loop.

Every member must remain physically valid. No electricity is required. Electrical
changes neither hide output nor pause methods or create restoration work. Physical
identity, scope, geometry and ownership are checked afresh at use and publication.
Writer stop or cable removal does not clear the display. Save/load retains committed models,
render progress, actual draw handles and shared spent credits. No user source or
render mutation runs on load. Unknown monitor state versions remain inert with
recovery data preserved.

## Row text presentation

Each terminal row is drawn as two native text objects in the mod font `tc-term`.
One object holds the background colours, the other holds the glyphs. Each byte
uses its own private-use character, so the game never reads guest text as rich text.
A changed row keeps its objects. The publication tick writes the new text and colours.
Unchanged rows make no native call. A full 126×84 grid uses at most 170 objects.

The font has the same 6×9 pixels as the glyph atlas. Known appearance differences:

- The engine draws text about 6 screen pixels below its target, at every zoom.
  Glyphs and backgrounds keep the same offset, so the content sits lower in the bezel.
- Cloud shadows do not dim the monitor content.
- At scale 0.5 and low zoom, a glyph pixel is smaller than a screen pixel.
  The text looks less smooth than the earlier sprites.

## Native world feedback and marking

Text and shapes draw above all sprite layers, including native feedback. While a tile of
a display is marked for deconstruction, the display hides its text, cursor and graphics
objects. The black panel stays visible, so the red X shows clearly. Cancel the mark to
show the content again. The model, the graphics ids and the publication do not change.
Selection boxes and wires can draw below the content.

Mark/cancel does not clear cells, change cursor/palette or regroup an array.
Only actual removal follows normal split/resize behavior.
Electrical changes affect neither content nor the engine's deconstruction order.
Saves from earlier releases convert their cell models to rows in one synchronized
step after the configuration change. The old cell sprites stay visible until the first
row frame publishes. Bounded retirement then destroys them.
See [RD4 evidence and the short client check](rd4-verification.md).

## Graphics mode

`m.setMode('graphics')` changes a display to graphics mode. `m.getMode()` reads the mode.
A real change clears the display and queues `monitor_resize` with reason `mode`.
In graphics mode, `getSize()` returns content pixels: 64 for each tile, minus the
4-pixel bezel. The origin is the top-left of the content area. X goes right and Y
goes down along the display's own axes.

Use `drawLine`, `drawPolygon`, `drawRectangle`, `drawCircle`, `drawArc`,
`drawText`, `drawSprite` and `drawLight`. Each call returns an id. Use `set(id, props)`
to move or change an object without a new object. Use `get`, `getObjects`,
`destroy`, `bringToFront`, `moveToBack` and `clear` to manage objects.
Changes show at the end of the same tick. A later error does not undo them.

Obey these rules:

- Every object must fit in the content area. The host does not clip. A call that
  leaves the area fails with `E_RANGE` and changes nothing.
- Sprites and lights always draw below lines, polygons, rectangles, circles, arcs and text.
  Overlapping sprites draw by position. `bringToFront` and `moveToBack` work only on the upper layer.
- Text uses only the terminal font. Each byte is `6*scale` by `9*scale` pixels.
  The text draws about 6 screen pixels below its box.
- Sprites accept only valid game icon paths, such as `item/iron-plate`.
- All monitor objects share `render_object_limit`. A draw call above it fails with `E_CAPACITY`.
- Terminal methods fail with `E_UNSUPPORTED` in graphics mode. Graphics methods fail in terminal mode.
- A graphics display cannot join a monitor synchronization group.
- Touch events report 0-based content pixels and `mode='graphics'`.

The mode follows merge, split, settings paste and blueprints like text scale.
Saves from earlier releases load in terminal mode. See
`examples/graphics-sine-chart.lua`, the in-game Reference tutorial Graphics sine
chart and the [exact API](player/api/monitor.md).

## Touch and resize callbacks

With an empty cursor and no open GUI, Ctrl + left click a world character cell.
The shared control is rebindable under Controls → Interact with computer / monitor.
It passes native game actions through and does not block reuse of held Ctrl.
There is no extra linked building/mining action. The actual clicked member must
be within native player reach and belong to the player's force/surface.
Bezel, letterboxing, outside, GUI-hover/focus and
physically unavailable interactions are ignored. Monitors need no electricity.
Each player activation is separate.

Register `computer.on('monitor_touch','touched')` or
`computer.on('monitor_resize','resized')`. Both add these fields to BaseEvent:
`peripheral`, `wire` (red preferred when both reachable), `wires` (red then green).
One event per subscription, not per physical path/tile/color. Authority is freshly
proved at delivery. Jobs keep recipient run IDs and generations. Thus, a later run cannot inherit
an earlier activation. Touch adds `x`, `y`, `player_index`, `sample_tick`.
Resize adds `old_width`, `old_height`, `width`, `height`, `reason` (`tiles`/`scale`).
Resize jobs and already queued resize snapshots coalesce to the latest geometry
while retaining the first old dimensions. Immediately before a resize callback,
the scheduler refreshes width/height from the current model under paid shared
work admission. This includes another writer's intervening callback in the same tick.
Removed identities discard pending jobs. Resize waits through peripheral outages.
Transient touch is dropped if its display/player no longer qualifies. Computer
queue overflow visibly faults that run through existing output cleanup.

Registration and cancellation maintain the recipient set. Notification ticks visit
only pending touches/resizes, never settled displays or unrelated computers.
Resize delivery retains display order and coalesces repeated changes into one job.
Cold load preserves those jobs, paid cursors and recipient membership. It does not
reconstruct them or execute callbacks in `on_load`.

## Bounds and alpha evidence

Development ceilings are:

- Independently 1..6 tiles on each axis
- 10584 cells/display
- 256 admitted tiles
- 80000 aggregate model cells
- 16384 bytes/write
- 64 pending touch activations.

Automatic buffering seals immutable actual-size snapshots
after callbacks, prepares replacements hidden and prepays complete native
publication. Existing programs need no flush. Newest pending snapshots coalesce.
Already admitted snapshots finish even under continuous writers. Preparation
and retirement share 1024 row steps/tick (`render_cells_per_tick`; the name is historical).

An optional selected group has at most four logical displays and 10584 combined
cells. Every member must participate before a round seals. All then publish in
one simulation tick. This is not a write lock or an application-frame detector.
See the [exact API and capacities](player/api/peripheral.md).

The 60000 baseline render reservation can grow to 160000 on demand, with baseline
service opportunities between boosts. It stays inside the configurable maintenance
reservation (default/minimum 200000), within the shared host envelope (default 5000000).
The separate 160000 whole-commit ceiling is unchanged by maintenance settings.
See [live mod settings](player/api/limits.md#live-mod-settings). Staging and queued retirement each retain at most
10584 cells and 256 frame records. Work refusal retains paid progress. The
256-tick stable-world target is checked headlessly, not a graphical/60-UPS promise.

`tests.monitor_engine` exercises model contracts, real wires/groups/rotations,
world row-text objects, all 256 glyph code points and maximum 6×6 geometry. It also checks shared
admission, queued-resize coalescence and cold presentation persistence. Its player
activation checks are explicitly table-backed mocks. Headless runs do not create
a native player or prove zoom/contrast/font/GUI input/multiplayer behavior.
Those native-client checks remain deferred to the user for this alpha.

For complete moving curves, use `examples/smooth-sine-chart.lua` and the
[bounded 30 Hz animation guide](player/monitor-animation.md). Dirty-row snapshots
update only the changed rows in place. Palette, clear and scroll changes rewrite every row
of the same objects. Initial images and geometry changes create new rows.

`examples/monitor-program.lua` is a native named-callback program, not an OS,
REPL, filesystem or terminal-redirection compatibility layer. Its source is
compiled/executed in the focused engine fixture, not claimed as client-typed.
