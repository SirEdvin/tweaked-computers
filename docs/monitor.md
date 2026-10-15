# In-world color monitors (API v1)

Place `tc-monitor` tiles with the same force, surface and cardinal orientation
next to each other. A complete rectangle shares one display. Holes, L-shapes
and arrays exceeding 4×4 partition deterministically: smallest world `(y,x,id)`
unassigned tile first, largest complete anchored rectangle, equal area preferring
world width then height. Every tile belongs to one rectangle.

Wire a computer's NETWORK port to any member's NETWORK port with red or green.
Use the explicit color in `peripheral.find('monitor','red')` or
`peripheral.wrap(name,'red')`. Geometric grouping never connects unwired member
ports: a red path cannot leave another member's green wire, or cross between
unwired members. Discovery still traverses actual mod-owned wires only.

## Calling the terminal

All methods use dot syntax. Extra arguments, combined color masks and implicit
number/string coercion are rejected. Ordinary failures are catchable ApiError
values (`E_ARGUMENT`, `E_RANGE`, `E_LIMIT`, `E_UNPOWERED`, `E_UNREACHABLE`,
`E_NETWORK_PENDING`); rejected calls leave the model unchanged. Shared callback
budget exhaustion is fatal, not a recoverable yield. Earlier accepted effects
remain committed.

| Method | Result / behavior |
| --- | --- |
| `write(text)` | No returns. One byte per cell; clips, never wraps; X advances by full byte length. |
| `blit(text,fg,bg)` | No returns. Equal byte lengths; color strings contain lowercase `0`–`f`; all validation precedes mutation. |
| `clear()` / `clearLine()` | No returns. Fill whole grid/current visible row with spaces/current colors; cursor unchanged. |
| `scroll(lines)` | No returns. Safe integer; positive upwards, negative downwards; exposed rows use current colors. Large offsets clear without offset-sized loops. |
| `getSize()` | Columns, rows. |
| `getCursorPos()` / `setCursorPos(x,y)` | Two safe integers / no returns. Offscreen positions allowed, writes clipped. Final X must remain safe. |
| `getCursorBlink()` / `setCursorBlink(bool)` | Boolean / no returns. Offscreen blink remains stored. |
| `getTextColor()` / `setTextColor(color)` | Foreground mask / no returns. |
| `getBackgroundColor()` / `setBackgroundColor(color)` | Background mask / no returns. |
| `isColor()` | `true`. |
| `setPaletteColor(color,rgb)` | No returns. Packed integer RGB 0–16777215. |
| `setPaletteColor(color,r,g,b)` | No returns. Exactly three finite channels 0–1. |
| `getPaletteColor(color)` | r, g, b. |
| `getTextScale()` / `setTextScale(scale)` | Number / no returns. Half-steps 0.5 through 5; initial 1. |
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

Initial cursor (1,1), blink false, white text, black background. Palette edits
recolor existing cells; palette entries are not copied into stored cell colors.
No rich text, newline/tab/escape execution or UTF-8 decoding occurs. Slots 32–126
are independent 6×9 ASCII glyphs; 128–159 are 2×3 mosaics with bits 0–4 selecting
the first five 3×3 foreground subcells, bottom-right always background. Other
bytes use an outlined replacement box. See `assets/README.md` for provenance.

## Geometry, identity and power

A tile is 64 logical units. The whole rectangle has a two-unit bezel per edge;
center the grid inside it. Columns = max(1,floor((64*W-4)/(6*scale))), rows =
max(1,floor((64*H-4)/(9*scale))). W/H follow local display right/down, rotated
clockwise with north/east/south/west. Rendering and touch use the same transform.
A 1×1 at scale 1 has 10×6 cells; 4×4 at 0.5 has 84×56 = 4704 cells.

The surviving anchor keeps its opaque logical identity. When multiple retained
anchors merge, the smallest stable anchor ID wins. Split rectangles without a
surviving anchor receive fresh names and inherit predecessor settings; removing
an anchor never retargets its old name. Changed character dimensions clear the
whole resulting buffer in retained current colors; cursor/blink are never
clamped. Same dimensions preserve cells. New independent displays use defaults.
Bounded pending regrouping explicitly refuses discovery with E_NETWORK_PENDING;
retry on a later callback/tick, not in a busy loop.

Every member must be electrically powered. Outages hide world output and refuse
active methods, retaining contents, palette, scale, cursor and identities. Power
restoration redraws retained contents without a fabricated resize. Writer stop
or cable removal does not clear the display. Save/load retains committed models,
render progress, actual draw handles and shared spent credits; no user source or
render mutation runs on load. Unknown monitor state versions remain inert with
recovery data preserved.

## Native world feedback and marking

Monitor content now uses explicit sprite layers above the body but below native
wires, selection and information icons. Mark the visible monitor body, not its
private power carrier. Mark/cancel does not clear cells, change cursor/palette or
regroup an array; only actual removal follows normal split/resize behavior.
Power loss hides content, not the engine's deconstruction order. No custom X is
drawn. Old saved render objects are rebuilt through admitted rendering/cleanup,
not on_load, while the committed display model remains intact.

The genuine red X's visible contrast and layering still require native graphical
review; exact-engine headless checks establish object properties and preserved
state only. See [RD4 evidence and the short client check](rd4-verification.md).

## Touch and resize callbacks

With an empty cursor and no open GUI, Ctrl + left click a world character cell.
The control is rebindable under Controls → Activate monitor character cell.
It consumes the corresponding game action, not an extra linked building/mining
action. The actual clicked member must be within native player reach and belong
to the player's force/surface. Bezel, letterboxing, outside, GUI-hover/focus and
unpowered interactions are ignored. Each player activation is separate.

Register `computer.on('monitor_touch','touched')` or
`computer.on('monitor_resize','resized')`. Both add these fields to BaseEvent:
`peripheral`, `wire` (red preferred when both reachable), `wires` (red then green).
One event per subscription, not per physical path/tile/color. Authority is freshly
proved at delivery; jobs retain recipient run IDs, so a later run cannot inherit
an earlier activation. Touch adds `x`, `y`, `player_index`, `sample_tick`.
Resize adds `old_width`, `old_height`, `width`, `height`, `reason` (`tiles`/`scale`).
Resize jobs and already queued resize snapshots coalesce to the latest geometry
while retaining the first old dimensions. Immediately before a resize callback,
the scheduler refreshes width/height from the current model under paid shared
work admission, covering another writer's intervening callback in the same tick.
Removed identities discard pending jobs. Resize waits through peripheral outages;
transient touch is dropped if its display/player no longer qualifies. Computer
queue overflow visibly faults that run through existing output cleanup.

## Bounds and alpha evidence

Development ceilings: 4×4 tiles/group, 4704 cells/group, 256 admitted tiles,
80000 aggregate cell ceiling (actual supported tile/geometry bounds stay below
it), 16384 bytes per write/color string, 64 pending touch activations. Rendering
checks up to 1024 cells per tick across displays, drawing only changed cells.
60000 work units are reserved inside—not on top of—the existing 200000
maintenance / 1000000 total tick envelope. Retired grids drain before another
geometry generation accumulates; work refusal retains exact sweep/job cursors.
The queried 256-tick render latency is a provisional development target, not a
frozen measured graphical or mixed-workload release guarantee. Continuous model
updates may keep a sweep dirty; once idle, a complete matching-revision sweep is
required before it is marked presented. Maximum-world integration belongs to
the final candidate's resource gate.

`tests.monitor_engine` exercises model contracts, real wires/groups/rotations,
world draw objects, all 256 atlas sprite slots, maximum 4×4 geometry, shared
admission, queued-resize coalescence and cold mid-sweep persistence. Its player
activation checks are explicitly table-backed mocks; headless runs do not create
a native player or prove zoom/contrast/font/GUI input/multiplayer behavior.
Those native-client checks remain deferred to the user for this alpha.

`examples/monitor-program.lua` is a native named-callback program, not an OS,
REPL, filesystem or terminal-redirection compatibility layer. Its source is
compiled/executed in the focused engine fixture, not claimed as client-typed.
