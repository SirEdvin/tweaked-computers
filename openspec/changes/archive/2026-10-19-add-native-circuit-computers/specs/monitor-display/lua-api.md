# Monitor Lua API v1

Normative companion to [spec.md](spec.md). Obtain with `peripheral.wrap(name, wire)` or `peripheral.find("monitor", wire)`. All calls below use dot syntax and the shared errors/authority rules in [common.md](../../api/common.md).

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

The logical display requires all member tiles powered. Losing power blanks world presentation and makes active methods unavailable while retaining contents/settings and grouping. Restoring power redraws the retained buffer, not an empty display or a fabricated resize event.

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

Required cases: negative/offscreen cursor clipping; nil/invalid color and blit atomicity; palette repaint; positive/negative/large scroll; all scales; merge/split/rotation identity and geometry; same-color reach through non-anchor tiles; touch on borders/corners; power restoration; cold retained display; glyph/rich-text safety; real-client maximum supported render latency.
