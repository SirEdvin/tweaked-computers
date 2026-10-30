# Monitor Lua API v1

Normative companion to [spec.md](spec.md). Obtain with `peripheral.wrap(name, wire)` or `peripheral.find("monitor", wire)`. All calls below use dot syntax and the shared errors/authority rules in [common.md](../../api/common.md).

The complete [buffering and synchronization API](buffering-api.md) is also normative: automatic fixed snapshots, checked group selection/status, actual-geometry capacities, lifecycle ownership and admission extend the unchanged terminal signatures below. [World interaction compatibility](../../api/device-experience.md) preserves native feedback, bezel sockets and touch coordinates.

## Methods

| Signature | Returns | Behavior |
| --- | --- | --- |
| `m.write(text)` | no values | String bytes become cells at the cursor; clip, do not wrap; advance X by byte length |
| `m.blit(text, foreground, background)` | no values | Equal byte lengths; each color byte is lowercase `0`..`f`; validate all before mutation |
| `m.clear()` | no values | Fill all cells with spaces/current colors; do not move cursor |
| `m.clearLine()` | no values | Clear current row if visible; do not move cursor |
| `m.scroll(lines)` | no values | Integer; positive moves contents upward, negative downward; newly exposed rows use spaces/current colors; cursor unchanged |
| `m.getSize()` | width, height | Current character dimensions, not physical tile dimensions |
| `m.getCursorPos()` | x, y | Integer cursor coordinates |
| `m.setCursorPos(x, y)` | no values | Integers; offscreen positions allowed within safe integer range, writes clipped |
| `m.getCursorBlink()` | boolean | Stored blink state |
| `m.setCursorBlink(enabled)` | no values | Boolean; invisible offscreen cursor remains logically enabled |
| `m.getTextColor()` / `getTextColour()` | color | Current foreground mask |
| `m.setTextColor(color)` / `setTextColour(color)` | no values | One valid color constant, not a combined mask |
| `m.getBackgroundColor()` / `getBackgroundColour()` | color | Current background mask |
| `m.setBackgroundColor(color)` / `setBackgroundColour(color)` | no values | One valid color constant |
| `m.isColor()` / `isColour()` | true | There is one color-capable monitor tier |
| `m.setPaletteColor(color, rgb)` / `setPaletteColour(color, rgb)` | no values | `rgb` is an integer 0..16777215 |
| `m.setPaletteColor(color, r, g, b)` / corresponding Colour alias | no values | Each channel finite and within 0..1; alternate overload, not extra optional args |
| `m.getPaletteColor(color)` / `getPaletteColour(color)` | r, g, b | Three numeric channels within 0..1 |
| `m.getTextScale()` | number | Initial 1; accepted scales are 0.5, 1, 1.5, …, 5 |
| `m.setTextScale(scale)` | no values | Recalculate geometry; clear and emit resize if dimensions change |
| `m.getLimits()` | table | `width_tiles`, `height_tiles`, `cells`, `write_bytes`, `render_latency_ticks`, plus common call caps |

`write`/`blit` do not interpret newline, carriage return, tab, Factorio rich text or terminal escape sequences. They are cell writes, not printing helpers. Numeric arguments are not silently rounded, and writes never mutate the buffer if final cursor arithmetic would leave the safe integer range. Scrolling at least the screen height clears all cells; very large offsets must be bounded without a proportional loop.

## Colors and cell geometry

`colors` and `colours` expose these constants and default palette values, indexed by the blit digit:

| Digit | Name | Mask | Default RGB |
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

Initial cursor is (1,1), blink false, foreground white, background black and text scale 1. Palette changes recolor already-stored cells; they do not replace stored color indexes.

Factorio geometry is intentionally not a claim of identical CC block resolution. A tile has 64 logical display units; the outer rectangle has a 2-unit bezel on each edge, and cells occupy `6*scale` by `9*scale` units. For W×H tiles measured along the display's local right/down axes (not necessarily the world's X/Y axes):

```text
columns = max(1, floor((64*W - 4) / (6*scale)))
rows    = max(1, floor((64*H - 4) / (9*scale)))
```

Center the resulting grid within the bezel. These logical units map uniformly to the world rectangle; geometry and touch must use the same transform. API coordinates rotate with the group's orientation: X goes right and Y down as viewed from the display's designated top. Cursor and palette are shared by all writers.

Text is byte/cell indexed, not Unicode grapheme indexed. V1 requires byte slots 32..126 as printable ASCII in an independently authored or independently licensed 6×9 atlas. Slots 128..159 provide a 2×3 mosaic: subtract 128, and bits 0..4 select foreground for the first five subcells in row-major order; unset bits and the bottom-right subcell use background. Each subcell is 3×3 logical units. Inverting foreground/background supplies complementary patterns. Every other byte renders one outlined replacement box and still consumes exactly one cell; control bytes are never executed. UTF-8 is not decoded by `write`/`blit`. The final glyph-slot manifest records this mapping and atlas provenance and must not contain the original CCPL font. Exercise ASCII, every mosaic slot and replacement behavior in client acceptance; no claim of arbitrary CC font-bitmap compatibility is made.

## Merge, split and resize

Grouping is geometric, not dependent on whether tiles are wired. A complete compatible rectangular component within bounds becomes one monitor; irregular/oversized components are partitioned deterministically into rectangles. The design specifies the partition and identity rule. A group can be reached through any wired member without creating an unwired discovery bridge between its connectors.

On merge, the surviving group's cursor, colors, scale and palette are retained. On split, resulting groups inherit those settings; the group containing the retained anchor keeps the name, others receive new names. Whenever character dimensions differ, clear the whole resulting buffer using retained current colors. Preserve cursor coordinates/blink even if temporarily offscreen; do not silently clamp them. Newly created independent displays use defaults. Removed identities detach; they are not aliases to unrelated new groups.

The custom logical display needs no electricity or electrical helper. Electrical cycling never blanks presentation or refuses methods. Live physical validity/ownership, geometry, scope and selected paths remain authoritative; physical unavailability can hide presentation without erasing retained contents/settings.

## Events

Use `computer.on("monitor_resize", "resized")` and `computer.on("monitor_touch", "touched")`. Events extend BaseEvent and include `peripheral`, `wire` and sorted `wires` as defined by discovery.

```text
-- Documentation additions to BaseEvent.
MonitorResize = {
  name = "monitor_resize", peripheral = PeripheralName,
  wire = Wire, wires = { Wire },
  old_width = integer, old_height = integer,
  width = integer, height = integer,
  reason = "tiles" | "scale"
}
MonitorTouch = {
  name = "monitor_touch", peripheral = PeripheralName,
  wire = Wire, wires = { Wire },
  x = integer, y = integer, player_index = integer,
  sample_tick = Tick
}
```

Resize notification is queued after new geometry is committed, so getSize agrees inside the callback. Touch maps a validated world activation to the current grid; bezel/outside/GUI-hover interactions are ignored. One interaction yields one event per registered computer subscription, not one per tile/path/color. New groups generate attach events; surviving resized groups generate resize events. Touch input uses a discoverable rebindable activation control and must not double-trigger normal building/mining actions. No mouse-drag, keyboard or terminal-redirection API is implied.

## Example: a touchable status display

```lua
function start(event)
  computer.on("monitor_touch", "touched")
  computer.on("monitor_resize", "resized")
  local m = peripheral.find("monitor", "red")
  if m then
    m.setBackgroundColor(colors.black)
    m.setTextColor(colors.lime)
    m.clear()
    m.setCursorPos(1, 1)
    m.write("READY")
  end
end

function touched(event)
  local m = peripheral.wrap(event.peripheral, event.wire)
  if m then
    m.setCursorPos(1, 1)
    m.write(tostring(event.x) .. "," .. tostring(event.y))
  end
end

function resized(event)
  local m = peripheral.wrap(event.peripheral, event.wire)
  if m then
    m.setCursorPos(1, 1)
    m.write("RESIZED")
  end
end
```

Required cases: negative/offscreen cursor clipping; nil/invalid color and blit atomicity; palette repaint; positive/negative/large scroll; all scales; merge/split/rotation identity and geometry; same-color reach through non-anchor tiles; touch on borders/corners; power-free operation and physical-availability recovery; cold retained display; glyph/rich-text safety; real-client maximum supported render latency.

## Demand-driven scheduling contract

## Public surface and exact results

All existing dot-call signatures, argument domains, Color/Colour aliases, glyph rules, clipping and per-call atomicity remain unchanged. No new `flush`, frame-control, queue-management, wait or polling method is introduced. No method acquires a hidden yield.

| Existing API | Exact result | Scheduling contract |
| --- | --- | --- |
| `m.write(text)`, `m.blit(text, foreground, background)` | Zero values | Validate and change the shared model before returning; coalesce presentation demand for the affected display/group. |
| `m.clear()`, `m.clearLine()`, `m.scroll(lines)` | Zero values | Preserve their current cell/cursor semantics and full-invalidation behavior where required; do not retain a command for later execution. |
| `m.setCursorPos(x, y)`, `m.setCursorBlink(enabled)` | Zero values | Preserve synchronous state and successful round participation, including valid no-ops. Native cursor blinking does not require recurring full-frame work. |
| `m.setTextColor(color)`, `m.setBackgroundColor(color)` and Colour aliases | Zero values | Preserve synchronous shared drawing state and participation; unchanged components need not be reconstructed. |
| Both documented overloads of `m.setPaletteColor(...)` and `m.setPaletteColour(...)` | Zero values | Preserve full validation, recoloring of stored color indexes and presentation invalidation; overloads and arity are not changed. |
| `m.setTextScale(scale)` | Zero values | Preserve the half-step domain, current dimensions, dimension-change clearing and resize notification; invalidate obsolete staging as required. |
| Existing monitor getters and `isColor()` / `isColour()` | Existing exact arity from the terminal contract | Read current shared model/state under existing guards, not a queued command result or an older visible image; do not drive rendering. |
| `m.getLimits()` | One defensive table | Preserve all existing keys/capacities and reachable static-metadata availability. No new scheduling knobs or limits. |
| `peripheral.setMonitorSyncGroup(members)` | Zero values | Preserve atomic registration, canonical deduplication, explicit wire binding, idempotence, run/shell ownership and clear-on-empty-array behavior. |
| `peripheral.getMonitorSyncGroup()` | One defensive `MonitorSyncStatus` table | Preserve existing fields, status meanings, sequence/tick acknowledgement and diagnostics. Readback does not drive rendering or retry an authority proof. |

Read-after-write is still synchronous even when the world is displaying the previous complete image. A later rejected call or callback failure does not undo earlier successful calls. Existing validation, work admission, copy-on-write and refusal atomicity remain binding.

### Presentation demand and synchronization

- Snapshot sealing remains after synchronized callback dispatch, never inside a callback. The canonical buffering contract's post-dispatch offer is an eligibility boundary, not a requirement to enumerate every unchanged monitor each tick.
- Repeated writes before that boundary coalesce demand. The existing bounded newest-pending snapshot sits behind an admitted immutable frame; new writes cannot restart that frame indefinitely or create an unbounded per-call queue.
- A selected group still requires a successful mutating operation on every member after registration or the preceding seal. A successful no-op counts; getters and rejected operations do not. A no-op round retains its sequence/publication semantics without requiring redundant native sprite reconstruction.
- A group with incomplete participation does not time out, fabricate missing writes or partially publish. Other independent eligible displays retain deterministic fair service.
- A stopped writer leaves its last complete physically valid image visible. Running a program elsewhere does not wake settled monitors. Preparation, ready publication, backpressure recovery and retirement already in progress continue without requiring new drawing.
- Native settings paste, topology/physical changes and ownership release also cause the necessary work. Drawing calls are not the only invalidation source.

### Availability, authority and physical changes

All tiles of a logical display must remain physically valid for active operations; no electricity is required. Physical unavailability can hide presentation without erasing the model; valid restoration can show retained state without a dummy write or artificial resize. Existing admission remains; electrical cycling schedules no hide/restore work.

One minimal live observation path retains physical-change detection. It does not grant durable authority: calls, touches and publication retain their operation-specific checks for identity, force/surface/geometry, owned components and required paths, including reachable static `getLimits()` metadata. Same-tick native changes must not reuse an earlier positive proof. Safe proof reuse within an operation known not to mutate physical state is unchanged.

Saved-program and Console selections retain their distinct principals. An idle Console selection must still be released after definitive path revocation even with the saved program stopped and no frame ready. Temporary incomplete proofs keep existing blocked/pending semantics; no silent wire fallback is added. Status reads report retained status under their existing contract rather than secretly retrying maintenance.

### Events, errors and limits

`monitor_touch`, `monitor_resize`, peripheral attach/detach and all existing payloads, ordering and deduplication rules remain unchanged. Committed geometry is readable when resize is delivered; touches never use obsolete visible geometry as if it were current. Deconstruction marking/cancellation is not actual topology removal and must not clear cells or invent a resize.

No new public error code is introduced. Existing `E_ARGUMENT`, `E_RANGE`, `E_UNREACHABLE`, `E_NETWORK_PENDING`, `E_BUSY`, `E_CAPACITY`, `E_LIMIT`, `E_NOT_FOUND` and unsupported-state handling retain their operation-specific meanings. In particular, ordinary queue backpressure does not turn an already accepted model update into a new guest-call failure or permit partial group publication.

Existing physical/model/selection, pending/staging/retirement, native-object, work and allocation ceilings remain binding. Frozen actual-tick maintenance reservations and spent credits survive repeated entry and cold load. This change does not raise limits to make a benchmark pass or promise zero-cost physical observation.

### Persistence and acceptance

Ordinary cold load preserves fronts, model state, selections, participation, pending snapshots and exact paid work. Upgrade from 0.1.16 initializes missing scheduling metadata through permitted synchronized work without executing guest code, clearing unchanged models or forcing unaffected complete fronts to rebuild. Unsupported retained representations stay recoverable and inactive rather than being silently reset.

Acceptance exercises burst writes, read-after-write, later failure, no-op participation, active and idle producers, settings paste, outages/restoration, same-event native mutations, idle Console revocation, topology/identity changes, all retained work phases and unchanged limits. Structural counters prove idle-work elision; matched 144-tile timing reports include both idle and active workloads without a fixed numerical performance gate. These checks do not by themselves establish graphical-client or connected-multiplayer acceptance.
