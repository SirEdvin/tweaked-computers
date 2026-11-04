---@meta

---Shared byte-cell terminal facade; obtain with peripheral.find('monitor', wire)
---or a checked wrap. Initial cursor (1,1), blink false, text white, background
---black and scale 1. Every writer shares cursor, colors, palette and contents.
---Calls mutate the model synchronously; getters see it even while an older
---complete image is displayed. Earlier accepted calls survive later failures.
---All paths retain exact physical/identity/scope/geometry checks; no electricity
---or electrical helper is required. Unavailability may hide but never erase state.
---
---### Cells, palette and geometry
---Text is byte/cell indexed, not Unicode. Printable ASCII occupies bytes 32..126.
---Bytes 128..159 are 2x3 mosaics: subtract 128; bits 0..4 select foreground in the
---first five row-major subcells, with the sixth/background unchanged. Swapping
---foreground/background supplies complementary patterns. Other bytes display one
---replacement box each. No newline, tab, carriage return, escape or Factorio rich
---text is interpreted. UTF-8 is not decoded. Glyph art is not a CC font promise.
---Palette changes recolor existing indices rather than changing stored cell colors.
---Default palette by digit 0..f: F0F0F0, F2B233, E57FD8, 99B2F2, DEDE6C, 7FCC19,
---F2B2CC, 4C4C4C, 999999, 4C99B2, B266E5, 3366CC, 7F664C, 57A64E, CC4C4C, 111111.
---
---Complete logical rectangles support independent local width/height 1..6 tiles,
---all half-step scales 0.5..5 and cardinal orientations. Irregular/oversized walls
---partition deterministically, not into one L-shaped framebuffer. For local W,H:
---columns=max(1,floor((64*W-4)/(6*scale))) and
---rows=max(1,floor((64*H-4)/(9*scale))). Query getSize, not a square-size guess.
---X is right and Y down as seen from the designated display top, not world axes.
---The grid is centered inside a two-logical-unit bezel; cells are 6x9 times scale.
---
---Grouping is geometric, independent of wiring. A wired member grants access to
---the logical screen but never bridges other members' circuits. Merge/split keeps
---surviving cursor/colors/scale/palette; new split identities are not old aliases.
---Changed character dimensions clear the resulting buffer with retained colors;
---cursor/blink are not clamped. Absorbed identities detach. Geometry-changing
---migration is not guaranteed to preserve images; ordinary cold load retains state.
---
---### Automatic complete-frame presentation
---After synchronized callback dispatch, dirty eligible screens offer immutable
---snapshots; unchanged screens are not polled into new frames. Calls before seal
---coalesce. Newest pending work can replace pending work, not an admitted snapshot.
---Old complete fronts remain during preparation; a callback's partial row edits
---are nevertheless its complete current model at seal. There is no flush,
---beginFrame/endFrame, debounce, term.redirect or window API. Group selection on
---peripheral synchronizes member participation/publication, not producer clocks.
---A valid no-op setter participates; getters and rejected calls do not. Stopped
---writers leave valid fronts visible; pending host work can finish independently.
---Native cursor blink needs no guest polling. Settings paste/physical changes also
---drive host work. Per-call admission, copy-on-write and retained limits still apply.
---
---### Events and lifecycle
---Register monitor_resize/monitor_touch through computer.on; see their TC event
---types. Touch ignores bezel/outside/GUI hover and obsolete visible geometry.
---One activation produces one event per registration, not per tile/path/color.
---Resize is queued after committed geometry; pending notifications may coalesce.
---Host notification service advances at most three recipients per call and
---retains unadmitted progress. A transient touch is dropped if its display/player
---becomes unavailable; resize work survives temporary display unavailability.
---Deconstruction marking alone is not removal and does not clear or resize.
---Cold load preserves models, fronts, selection/participation, pending snapshots
---and paid progress without guest replay. Unsupported retained state is recoverable
---but inactive, not silently reset. Bounds are safety envelopes, not measured FPS,
---universal heap guarantees or completed maximum-latency acceptance.
---@class TC.Monitor
local Monitor = {}

---Write bytes at the cursor, clipping without wrapping. Advance X by complete
---byte length even offscreen; reject unsafe final cursor arithmetic before any
---mutation. Numeric text is not implicitly converted. Returns zero values.
---@param text string Bounded bytes; control/rich-text bytes are literal cells.
function Monitor.write(text) end

---With string foreground, validate all three equal-length byte strings before
---writing/advancing cursor. Foreground/background contain lowercase 0..f only.
---The current compatibility exception accepts nil/false foreground, uses current
---colors and ignores the third argument; all three positions are still required.
---No partial write on invalid strings, admission or unsafe cursor arithmetic.
---Returns zero values in both forms. This documents existing behavior, not a new
---permission for omitted arguments or general color coercion.
---@overload fun(text: string, foreground: nil|false, background: TC.GuestValue) # text is literal bounded bytes; nil/false foreground uses current colors; background is required but ignored, subject to guarded argument admission. Returns zero values.
---@param text string Literal cell bytes, bounded by write_bytes.
---@param foreground string One lowercase palette digit per text byte.
---@param background string One lowercase palette digit per text byte.
function Monitor.blit(text, foreground, background) end

---Fill all cells with spaces/current colors; cursor unchanged. Zero results.
function Monitor.clear() end

---Clear the current row when visible; offscreen is a valid no-op. Cursor unchanged.
---Returns zero values; a successful no-op still participates in a selected round.
function Monitor.clearLine() end

---Move contents vertically; new rows are spaces/current colors. Positive moves
---up, negative down. Magnitude at least the height clears the screen without a
---proportional loop. Cursor unchanged; returns zero values.
---@param lines integer Signed safe-integer row offset; no float/string coercion.
function Monitor.scroll(lines) end

---Read current model geometry, not physical tiles or an older visible snapshot.
---@return integer width Positive character column count.
---@return integer height Positive character row count.
function Monitor.getSize() end

---Read the shared cursor, including valid offscreen coordinates.
---@return integer x Signed safe-integer character column.
---@return integer y Signed safe-integer character row.
function Monitor.getCursorPos() end

---Set exact shared cursor coordinates; offscreen positions are legal. Clipping
---occurs on writes, not by clamping the cursor. Returns zero values.
---@param x integer Safe integer -9007199254740991..9007199254740991.
---@param y integer Safe integer -9007199254740991..9007199254740991.
function Monitor.setCursorPos(x, y) end

---Read stored blink state even when the cursor is offscreen and invisible.
---@return boolean enabled Current shared blink setting.
function Monitor.getCursorBlink() end

---Set shared blink state; no guest polling is needed. Returns zero values.
---@param enabled boolean Required exact boolean, not truthiness coercion.
function Monitor.setCursorBlink(enabled) end

---Read the shared foreground palette index.
---@return TC.Color color One valid single color mask.
function Monitor.getTextColor() end

---Exact alias of getTextColor, with identical result arity and behavior.
Monitor.getTextColour = Monitor.getTextColor

---Set foreground; recoloring existing cells requires palette changes instead.
---Returns zero values. Combined color masks are invalid.
---@param color TC.Color One exact color constant.
function Monitor.setTextColor(color) end

---Exact alias of setTextColor, including admission and zero results.
Monitor.setTextColour = Monitor.setTextColor

---Read the shared background palette index.
---@return TC.Color color One valid single color mask.
function Monitor.getBackgroundColor() end

---Exact alias of getBackgroundColor, including result arity.
Monitor.getBackgroundColour = Monitor.getBackgroundColor

---Set the background used by later writes/clears. Returns zero values.
---@param color TC.Color One exact color constant; no combined masks.
function Monitor.setBackgroundColor(color) end

---Exact alias of setBackgroundColor, including zero results.
Monitor.setBackgroundColour = Monitor.setBackgroundColor

---The only supported monitor tier is color-capable.
---@return true supported Exactly one true result.
function Monitor.isColor() end

---Exact alias of isColor; returns exactly one true value.
Monitor.isColour = Monitor.isColor

---Set one shared palette entry, recoloring all cells using that index. Exactly
---two call shapes: color,rgb or color,r,g,b. Never a three-argument partial RGB
---form, nil-filled optional channels or rounded integer. Returns zero values.
---@param color TC.Color Exact palette index to replace.
---@param r number Red channel in 0..1 for the four-argument form.
---@param g number Green finite channel in 0..1.
---@param b number Blue finite channel in 0..1.
---@overload fun(color: TC.Color, rgb: integer) # rgb is one packed integer 0..16777215 (0xRRGGBB), not a unit red channel; returns zero values.
function Monitor.setPaletteColor(color, r, g, b) end

---Exact alias of setPaletteColor, preserving both overloads and zero results.
Monitor.setPaletteColour = Monitor.setPaletteColor

---Read current palette channels; preserve three ordered result positions.
---@param color TC.Color One exact palette index.
---@return number r Red finite channel in 0..1.
---@return number g Green finite channel in 0..1.
---@return number b Blue finite channel in 0..1.
function Monitor.getPaletteColor(color) end

---Exact alias of getPaletteColor, including all three results.
Monitor.getPaletteColour = Monitor.getPaletteColor

---Read shared text scale; independent of world footprint or client GUI scale.
---@return number scale One of the half steps 0.5,1,1.5,2,2.5,3,3.5,4,4.5,5.
function Monitor.getTextScale() end

---Set a half-step scale and recalculate dimensions. If dimensions change, clear
---the model with current colors and queue resize; retain cursor/blink. Geometry
---changes invalidate staging/round participation and can block an oversized sync
---group. No implicit widening of its cell allowance. Returns zero values.
---@param scale number Exact half-step from 0.5 through 5; no numeric coercion.
function Monitor.setTextScale(scale) end

---Read a defensive monitor-specific limit map. This is reachable metadata, not
---permission to draw without current physical authority. Public dispatch requires
---zero arguments (E_ARGUMENT otherwise), including explicit nil. No common keys
---are implied beyond the actual monitor-specific map.
---@return TC.MonitorLimits limits Current monitor/model/presentation envelopes.
function Monitor.getLimits() end
