# Merged monitors and terminal methods

Place compatible monitor tiles adjacent with matching force, surface and cardinal
orientation. Every complete rectangle from 1×1 through 6×6 shares one screen, including 1×6, 3×6 and 6×3. Holes, L-shapes and
oversized arrays partition deterministically: smallest world `(y,x,id)` tile first,
largest complete anchored rectangle, equal area prefers world width then height.
No member needs electricity. Connect computer NETWORK red/green to any member NETWORK.
Shared display content is not a wire bridge between unwired members or colors.

In 0.1.9, monitor items stack to 50 while remaining item-with-tags. Native tags,
labels and quality must match; unlike state is not silently merged. Mining and
replacement retain the existing settings/palette contract, not a portable screen
buffer. Computer and KV items still stack to one.

Obtain `local m = peripheral.find("monitor", "red")`, or wrap an exact name/color.
All methods are dot calls. No extra arguments, implicit coercion or combined color
masks. Every operation uses current authority; see [shared errors](common.md#errors).
Rejected validation/admission leaves the current operation unchanged; earlier
successful calls are not rolled back.

## Automatic buffered presentation

Existing methods need no flush or registration. They update the shared model
before returning; reads and other authorized writers see it immediately. After
callbacks, the host captures fixed immutable cells/palette/cursor/geometry and
prepares replacements invisibly. The previous complete image remains until a
whole publication is admitted. New writes coalesce behind an admitted frame,
which finishes rather than restarting forever. No hidden yield or callback-wide
transaction is introduced. A first write after capture pays for a copy-on-write
cell root; clear/scroll already replace their roots. Rejected calls preserve both
the model and its snapshot/participation bookkeeping.

Presentation is demand-driven. A settled display keeps its complete image and
native cursor blink without recurring snapshot/cell preparation. A writer on an
independent screen does not wake unchanged peers. Successful no-op setters still
participate in selected rounds; getters do not enqueue presentation. Incomplete
rounds and unavailable displays wait for the corresponding participation or physical
transition, while admitted preparation, backpressure retries and retirement keep
their existing bounded fair service.

Placement/removal, physical changes, settings paste and ownership changes
also wake the necessary work; a dummy drawing call is not required. Stable walls
do not repeatedly rebuild topology signatures. Targeted invalidations and
staggered due non-power observations retain the existing 60-tick topology
envelope; an unrelated idle tile is not visited every tick. Calls, touch and
publication still prove fresh authority, so an earlier observation never
authorizes a later same-tick call. Signal subscriptions still sample each tick.
There is no new frame API, queue limit or budget setting.

For several independently grouped screens, optionally use
`peripheral.setMonitorSyncGroup(members)` and `peripheral.getMonitorSyncGroup()`;
see [selection and status](peripheral.md#synchronized-monitor-presentation).
This aligns presentation epochs, not independent program clocks. A program that
draws four rows and returns still creates a legitimate intermediate application
image; buffering cannot infer that later callbacks will finish the plot.

## Complete terminal reference

| Signature | Exact returns and behavior |
| --- | --- |
| `m.write(text)` | None. One byte/cell; clip without wrapping; X advances full byte length |
| `m.blit(text, foreground, background)` | None. Equal byte lengths; fg/bg lowercase `0`–`f`; validate all first |
| `m.clear()` | None. Whole grid spaces/current colors; cursor unchanged |
| `m.clearLine()` | None. Current visible row spaces/current colors; cursor unchanged |
| `m.scroll(lines)` | None. Safe integer; positive up, negative down, exposed rows current colors; cursor unchanged |
| `m.getSize()` | width, height as integer character columns/rows |
| `m.getCursorPos()` | x, y safe integers, initially 1,1 |
| `m.setCursorPos(x, y)` | None. Safe integers; offscreen allowed, writes clip; final X must remain safe |
| `m.getCursorBlink()` | Boolean, initially false |
| `m.setCursorBlink(enabled)` | None. Boolean; offscreen state retained |
| `m.getTextColor()` / `m.getTextColour()` | One foreground mask, initially white |
| `m.setTextColor(color)` / `m.setTextColour(color)` | None. One valid mask |
| `m.getBackgroundColor()` / `m.getBackgroundColour()` | One background mask, initially black |
| `m.setBackgroundColor(color)` / `m.setBackgroundColour(color)` | None. One valid mask |
| `m.isColor()` / `m.isColour()` | true |
| `m.setPaletteColor(color, rgb)` / `m.setPaletteColour(color, rgb)` | None. Packed integer RGB 0–16777215 |
| `m.setPaletteColor(color, r, g, b)` / `m.setPaletteColour(color, r, g, b)` | None. Alternate overload: exactly three finite channels 0–1 |
| `m.getPaletteColor(color)` / `m.getPaletteColour(color)` | r, g, b in 0–1 |
| `m.getTextScale()` | Number, initially 1 |
| `m.setTextScale(scale)` | None. Half-steps 0.5,1,…,5; geometry recalculated |
| `m.getLimits()` | Defensive common + monitor capacities |

There is no terminal global/redirection, newline, tab, escape, rich-text or Unicode
interpretation. write/blit always consume one cell per byte, including unsupported
control bytes. Large scroll amounts clear without an offset-sized loop.
Cursor/colors/palette are shared by all writers. Palette changes recolor existing
cells; cell storage retains color indexes, not copied RGB triples.

## Colors and glyphs

`colors` and `colours` are the **same** immutable namespace. These are all constants;
no additional CC color utility methods are implied. Use one mask, never a sum.

| Blit digit | Name(s) | Mask | Initial RGB hex |
| --- | --- | ---: | --- |
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

Bytes 32–126 use independent 6×9 ASCII glyphs. Bytes 128–159 are 2×3 mosaics:
subtract 128; bits 0–4 select the first five row-major 3×3 foreground subcells;
bottom-right always background. Swap foreground/background for complementary
patterns. Other bytes render one outlined replacement box. UTF-8 is not decoded.

<a id="geometry-identity-and-power"></a>

## Geometry, identity and availability

Each tile is 64 logical display units, with a two-unit bezel per outer edge.
Columns = max(1,floor((64×W−4)/(6×scale))); rows =
max(1,floor((64×H−4)/(9×scale))). W/H follow display-local right/down, rotated
clockwise by orientation, not necessarily world X/Y. The grid is centered.
A 1×1 scale-1 display is 10×6; 6×6 at 0.5 is 126×84 (10,584 cells).
At scale 1, 3×6 is 31×42 and 6×3 is 63×20. Buffers use actual grids, not square padding.

Surviving anchor keeps the logical name; multiple retained anchors merge under the
smallest stable anchor ID. Splits without a surviving anchor receive fresh names
and inherit settings. Removed names do not alias replacements. Changed character
dimensions clear the whole resulting image in current colors; same dimensions
preserve cells. Cursor/blink stay even offscreen. New independent screens use defaults.

All members must be physically valid; none needs electricity. Electrical cycling
never blanks presentation or refuses custom methods. Physical unavailability can
hide presentation while retaining model/settings/identity. Valid restoration
redraws without fake resize; definitive path/identity loss releases a selection. Stop
or cable removal does not clear the screen. Ordinary load retains model/render
progress without executing user source. Mining retains tile settings, not the
obsolete merged image. Pending regroup returns E_NETWORK_PENDING; retry later.

## Touch and resize events

Use `computer.on("monitor_touch", "touched")` and/or
`computer.on("monitor_resize", "resized")`. Each extends BaseEvent with
`peripheral:string`, `wire:Wire` and `wires:Wire[]` (red then green, wire is first).
One event per subscription, not per path/tile/color; duplicate registrations are
still independent. Current authority and recipient run are checked at delivery.

- Touch adds `x:integer`, `y:integer`, `player_index:integer`, `sample_tick:Tick`.
  With empty cursor/no other GUI, Ctrl+left-click a cell (rebindable shared
  **Interact with computer / monitor** action). Clicked member must be in native reach and same
  force/surface. Bezel, letterbox, GUI hover/focus, outside or physically invalid activation
  is ignored. No building/mining double action, mouse drag or keyboard API implied.
- Resize adds `old_width`, `old_height`, `width`, `height` integers and
  `reason="tiles"/"scale"`. Commit geometry before notification. Coalescing keeps
  first old dimensions and latest current dimensions, refreshed before dispatch.
  getSize agrees in the callback. New groups attach; surviving groups resize.
  Native settings paste also queues this notification when its scale change
  changes character dimensions; it does not fabricate guest round participation.

Resize waits through outages. Touch is transient and drops if display/player
no longer qualifies. Removed identities discard jobs. Computer queue overflow
faults that run and triggers owned-output cleanup.

## Bounds, example and troubleshooting

Device limits: width_tiles=6, height_tiles=6, cells=10584, write_bytes=16384;
256 admitted tiles, 80,000 aggregate model cells, 64 pending touches. Preparation
and retirement share 1,024 cell checks/tick. Pending snapshots cap at 80,000 cells;
admitted staging and queued retirement each cap at 10,584 cells and 256 frames.
Invalid fronts remain accounted until retirement can accept them. Queried bounds
include render_commit_objects=42352, render_commit_work=160000,
render_object_limit=203872 and render_retained_cells=362336 logical cell slots
(not host bytes). The 60,000 baseline reservation can boost to 160,000, with a
baseline opportunity between boosts, inside the configurable maintenance
reservation (default/minimum 200,000) within the shared host ceiling (default 5,000,000).
Increasing maintenance does not raise the separate 160,000 whole-commit ceiling.
See [live mod settings](limits.md#live-mod-settings). Exact progress and spent credits survive cold load.
The 256-tick stable-world render target is provisional, not a 60-UPS/FPS or
graphical-latency guarantee. Continuous producers retain bounded newest-pending
state while complete admitted frames still publish.

Run [monitor-program](../examples.md#monitor-program) to draw READY and echo touch
coordinates/resize. For bounded whole-curve animation, use
[smooth-sine-chart](../examples.md#smooth-sine-chart); the
[30 Hz design and verification boundaries](../monitor-animation.md) explain
dirty-cell presentation, supported test layouts and why this is not a universal
client-FPS guarantee. If text clips, query getSize, move cursor explicitly and avoid
newlines. If grouping surprises you, inspect orientation, holes and 6×6 bounds.
Check every tile's physical validity; electricity has no effect on the custom display.
For wrong touch coordinates check local rotation and actual cells rather than the
bezel. Representative native Ctrl-click and monitor-touch cases are verified in
base and Space Age; exhaustive layouts/platforms and busy-factory input latency
remain alpha testing, not a universal client guarantee.

Back up before upgrading from 0.1.4. Unchanged saved walls are reevaluated under
the six-tile policy: absorbed names detach, surviving anchors retain settings,
and changed character dimensions clear contents and notify resize. Unaffected
complete images are adopted under paid work; partial legacy sweeps rebuild.
Ordinary load performs no rendering or source execution. Roll back with the
pre-upgrade save and matching old mod, not an in-place downgrade of new buffers.
