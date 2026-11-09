---@meta

---This is a shared byte-cell terminal facade.
---Use peripheral.find('monitor', wire) or a checked wrap to get the facade.
---Initial settings are cursor (1,1), blink false, white text, black background and scale 1.
---Every writer shares the cursor, colors, palette and contents.
---
---Calls change the model synchronously.
---Getters read that model even while the display shows an older complete image.
---Earlier accepted calls survive later failures.
---All paths retain exact physical, identity, scope and geometry checks.
---No electricity or electrical helper is necessary.
---Unavailability can hide state but never erase it.
---
---### Modes
---A logical monitor is in terminal mode (the default) or graphics mode. See getMode and setMode.
---Terminal mode is the byte-cell terminal described below.
---Graphics mode holds retained native objects in monitor pixels; see drawLine and the methods after it.
---In graphics mode, write, blit, clearLine, scroll, the cursor, colour, palette and text-scale methods, and their aliases, raise E_UNSUPPORTED.
---In terminal mode, the draw methods, set, get, getObjects, destroy, bringToFront and moveToBack raise E_UNSUPPORTED.
---getMode, setMode, getSize, clear, isColor and getLimits work in both modes.
---Monitor synchronization groups accept only terminal-mode monitors.
---
---### Cells, palette and geometry
---Text uses byte/cell indexes, not Unicode.
---Printable ASCII occupies bytes 32..126.
---Bytes 128..159 are 2x3 mosaics.
---Subtract 128 to get the mosaic bits.
---Bits 0..4 select the foreground in the first five row-major subcells; the sixth subcell remains the background.
---An exchange of foreground and background gives complementary patterns.
---
---Other bytes each display one replacement box.
---The monitor does not interpret newline, tab, carriage return, escape or Factorio rich text.
---It does not decode UTF-8.
---Glyph art does not guarantee a CC font.
---Palette changes recolor existing indices instead of changing stored cell colors.
---Default palette by digit 0..f: F0F0F0, F2B233, E57FD8, 99B2F2, DEDE6C, 7FCC19,
---F2B2CC, 4C4C4C, 999999, 4C99B2, B266E5, 3366CC, 7F664C, 57A64E, CC4C4C, 111111.
---
---Complete logical rectangles support independent local width and height of 1..6 tiles, all half-step scales 0.5..5, and cardinal orientations.
---Irregular or oversized walls partition deterministically, not into one L-shaped framebuffer.
---For local W,H:
---columns=max(1,floor((64*W-4)/(6*scale))) and
---rows=max(1,floor((64*H-4)/(9*scale))).
---Query getSize instead of guessing a square size.
---
---X is right and Y is down from the designated display top, not along world axes.
---The grid is centered inside a two-logical-unit bezel.
---Cells are 6x9 times scale.
---
---Grouping is geometric and independent of wiring.
---A wired member grants access to the logical screen but never bridges the circuits of other members.
---Merge and split retain the surviving cursor, colors, scale and palette.
---New split identities are not old aliases.
---
---Changed character dimensions clear the resulting buffer with retained colors.
---The cursor and blink are not clamped.
---Absorbed identities detach.
---Migration that changes geometry does not guarantee image preservation.
---Ordinary cold load retains state.
---
---### Automatic complete-frame presentation
---After synchronized callback dispatch, dirty eligible screens offer immutable snapshots.
---Unchanged screens do not cause polling for new frames.
---Calls before seal coalesce.
---The newest pending work can replace pending work, not an admitted snapshot.
---
---Old complete fronts remain during preparation.
---A callback's partial row edits are nevertheless its complete current model at seal.
---There is no flush, beginFrame/endFrame, debounce, term.redirect or window API.
---Group selection on peripheral synchronizes member participation and publication, not producer clocks.
---A valid no-op setter participates; getters and rejected calls do not.
---
---Stopped writers leave valid fronts visible.
---Pending host work can finish independently.
---Native cursor blink needs no guest polling.
---Settings paste and physical changes also cause host work.
---Per-call admission, copy-on-write and retained limits still apply.
---
---### Events and lifecycle
---Register monitor_resize and monitor_touch through computer.on.
---See their TC event types.
---Touch ignores the bezel, outside areas, GUI hover and obsolete visible geometry.
---One activation produces one event per registration, not per tile, path or color.
---Resize enters the queue after geometry commit; pending notifications can coalesce.
---
---The host notification service advances at most three recipients per call and retains unadmitted progress.
---A transient touch is dropped if its display or player becomes unavailable.
---Resize work survives temporary display unavailability.
---Deconstruction marking alone is not removal and does not clear or resize the display.
---
---Cold load preserves models, fronts, selection, participation, pending snapshots and paid progress without guest replay.
---Unsupported retained state is recoverable but inactive; no silent reset occurs.
---Bounds are safety envelopes, not measured FPS, universal heap guarantees or completed maximum-latency acceptance.
---@class TC.Monitor
local Monitor = {}

---Write bytes at the cursor with clipping but no wrapping.
---The method advances X by the complete byte length, even offscreen.
---It rejects unsafe final cursor arithmetic before any mutation.
---It does not implicitly convert numeric text.
---The method returns zero values.
---@param text string Bounded bytes. Control and rich-text bytes are literal cells.
function Monitor.write(text) end

---With string foreground, the method validates all three equal-length byte strings before writes or cursor movement.
---Foreground and background contain only lowercase 0..f.
---The current compatibility exception accepts nil or false foreground.
---That form uses current colors and ignores the third argument, but all three positions remain required.
---
---Invalid strings, failed admission or unsafe cursor arithmetic cause no partial write.
---Both forms return zero values.
---This is existing behavior, not new permission for omitted arguments or general color coercion.
---@overload fun(text: string, foreground: nil|false, background: TC.GuestValue) # text is literal bounded bytes. A nil or false foreground uses current colors. background is required but ignored, subject to protected-value rules but no temporary-allocation admission. The method returns zero values.
---@param text string Literal cell bytes, bounded by write_bytes.
---@param foreground string One lowercase palette digit per text byte.
---@param background string One lowercase palette digit per text byte.
function Monitor.blit(text, foreground, background) end

---In terminal mode, fill all cells with spaces and current colors.
---The cursor stays unchanged.
---In graphics mode, destroy every graphics object. Ids are not reused afterwards.
---The method returns zero values.
function Monitor.clear() end

---If the current row is visible, clear it.
---An offscreen row is a valid no-op.
---The cursor stays unchanged.
---The method returns zero values.
---A successful no-op still participates in a selected round.
function Monitor.clearLine() end

---Move contents vertically.
---New rows contain spaces and current colors.
---Positive values move contents up; negative values move them down.
---A magnitude at least equal to the height clears the screen without a proportional loop.
---The cursor stays unchanged.
---The method returns zero values.
---@param lines integer Signed safe-integer row offset. There is no float or string coercion.
function Monitor.scroll(lines) end

---Read the current model geometry, not physical tiles or an older visible snapshot.
---In graphics mode the results are content pixels: 64*W-4 by 64*H-4 for a W×H tile display.
---@return integer width Positive character column count, or content pixel width in graphics mode.
---@return integer height Positive character row count, or content pixel height in graphics mode.
function Monitor.getSize() end

---Read the shared cursor, including valid offscreen coordinates.
---@return integer x Signed safe-integer character column.
---@return integer y Signed safe-integer character row.
function Monitor.getCursorPos() end

---Set the exact shared cursor coordinates.
---Offscreen positions are permitted.
---Writes use clipping; the cursor is not clamped.
---The method returns zero values.
---@param x integer Safe integer -9007199254740991..9007199254740991.
---@param y integer Safe integer -9007199254740991..9007199254740991.
function Monitor.setCursorPos(x, y) end

---Read the stored blink state even when the cursor is offscreen and invisible.
---@return boolean enabled Current shared blink setting.
function Monitor.getCursorBlink() end

---Set the shared blink state.
---No guest polling is necessary.
---The method returns zero values.
---@param enabled boolean Required exact boolean, without truthiness coercion.
function Monitor.setCursorBlink(enabled) end

---Read the shared foreground palette index.
---@return TC.Color color One valid single color mask.
function Monitor.getTextColor() end

---This is an exact alias of getTextColor, with identical result arity and behavior.
Monitor.getTextColour = Monitor.getTextColor

---Set the foreground.
---Palette changes are necessary to recolor existing cells.
---The method returns zero values.
---Combined color masks are invalid.
---@param color TC.Color One exact color constant.
function Monitor.setTextColor(color) end

---This is an exact alias of setTextColor, with the same admission and zero results.
Monitor.setTextColour = Monitor.setTextColor

---Read the shared background palette index.
---@return TC.Color color One valid single color mask.
function Monitor.getBackgroundColor() end

---This is an exact alias of getBackgroundColor, with the same result arity.
Monitor.getBackgroundColour = Monitor.getBackgroundColor

---Set the background for later writes and clears.
---The method returns zero values.
---@param color TC.Color One exact color constant; no combined masks.
function Monitor.setBackgroundColor(color) end

---This is an exact alias of setBackgroundColor, with the same zero results.
Monitor.setBackgroundColour = Monitor.setBackgroundColor

---The only supported monitor tier has color capability.
---@return true supported Exactly one true result.
function Monitor.isColor() end

---This is an exact alias of isColor.
---It returns exactly one true value.
Monitor.isColour = Monitor.isColor

---Set one shared palette entry.
---This recolors all cells that use that index.
---There are exactly two call shapes: color,rgb or color,r,g,b.
---The method does not accept a three-argument partial RGB form, nil-filled optional channels or a rounded integer.
---The method returns zero values.
---@param color TC.Color Exact palette index to replace.
---@param r number Red channel in 0..1 for the four-argument form.
---@param g number Green finite channel in 0..1.
---@param b number Blue finite channel in 0..1.
---@overload fun(color: TC.Color, rgb: integer) # rgb is one packed integer 0..16777215 (0xRRGGBB), not a unit red channel. The method returns zero values.
function Monitor.setPaletteColor(color, r, g, b) end

---This is an exact alias of setPaletteColor, with both overloads and zero results unchanged.
Monitor.setPaletteColour = Monitor.setPaletteColor

---Read the current palette channels.
---The method preserves three ordered result positions.
---@param color TC.Color One exact palette index.
---@return number r Red finite channel in 0..1.
---@return number g Green finite channel in 0..1.
---@return number b Blue finite channel in 0..1.
function Monitor.getPaletteColor(color) end

---This is an exact alias of getPaletteColor, with all three results unchanged.
Monitor.getPaletteColour = Monitor.getPaletteColor

---Read the shared text scale.
---It is independent of the world footprint and client GUI scale.
---@return number scale One of the half steps 0.5,1,1.5,2,2.5,3,3.5,4,4.5,5.
function Monitor.getTextScale() end

---Set a half-step scale.
---The method recalculates dimensions.
---If dimensions change, it clears the model with current colors and queues resize, but retains the cursor and blink.
---Geometry changes invalidate staging and round participation, and can block an oversized sync group.
---The cell allowance does not implicitly increase.
---The method returns zero values.
---@param scale number Exact half-step from 0.5 through 5. There is no numeric coercion.
function Monitor.setTextScale(scale) end

---Read a defensive monitor-specific limit map.
---This is reachable metadata, not permission to draw without current physical authority.
---Public dispatch requires zero arguments.
---Any argument, also explicit nil, causes E_ARGUMENT.
---No common keys are implied beyond the actual monitor-specific map.
---@return TC.MonitorLimits limits Current monitor/model/presentation envelopes.
function Monitor.getLimits() end

---### Graphics mode
---Read the current mode.
---@return TC.MonitorMode mode Current mode of the logical display.
function Monitor.getMode() end

---Change the mode.
---A change to the other mode clears all terminal cells (to spaces with current colors) and destroys all graphics objects.
---It then queues monitor_resize with reason 'mode'; old dimensions use the old units.
---It removes this monitor from a monitor synchronization group when it enters graphics mode.
---Cursor, colors, palette and text scale are retained for a later return to terminal mode.
---Setting the current mode changes nothing and is a successful mutating call for synchronization rounds.
---The mode persists through save/load and follows merge, split, settings paste and blueprints like text scale.
---The method returns zero values.
---@param mode TC.MonitorMode Exact 'terminal' or 'graphics'. Any other string causes E_RANGE; a non-string causes E_ARGUMENT.
function Monitor.setMode(mode) end

---This is one of the two monitor modes.
---@alias TC.MonitorMode 'terminal'|'graphics'

---This is a positive integer that identifies one graphics object of one logical display.
---Ids are never reused for that display, also after clear.
---A geometry change, mode change or new logical identity removes all objects; their ids then return nil from get.
---@alias TC.GraphicsObjectId integer

---This is a point in content pixels: 64 per tile, origin at the content top-left (two pixels inside the bezel), x right, y down along the display's own axes.
---Either array form {x, y} or map form {x=..., y=...} is accepted. get returns the map form.
---Both coordinates are finite numbers; fractions are allowed.
---@class TC.GraphicsPoint
---@field x number Horizontal content pixel.
---@field y number Vertical content pixel.

---This is a Factorio colour table with channels 0..1.
---Either array form {r, g, b, a} or map form {r=..., g=..., b=..., a=...} is accepted. get returns the map form.
---A channel outside 0..1, or a non-finite channel, causes E_RANGE. Colour constants from colors are not accepted (E_ARGUMENT).
---@class TC.GraphicsColor
---@field r number Red 0..1.
---@field g number Green 0..1.
---@field b number Blue 0..1.
---@field a? number Alpha 0..1. Default: 1.

---These properties are accepted by every draw method and by set.
---Any key not listed for the object type causes E_ARGUMENT, also native keys such as surface, target entities, players, forces, time_to_live, render_mode and draw_on_ground.
---Every object must fit the content area completely, or the call causes E_RANGE with no change. The host never clips or clamps.
---@class TC.GraphicsCommon
---@field visible? boolean Default: true. A hidden object keeps its id, order and bounds check.
---@field blink_interval? integer Native blink period in ticks, 0..65535. Default: 0 (no blinking).
---@field only_in_alt_mode? boolean Default: false.

---These are the properties of a straight line.
---@class TC.GraphicsLine: TC.GraphicsCommon
---@field from TC.GraphicsPoint Start point.
---@field to TC.GraphicsPoint End point.
---@field color TC.GraphicsColor Line colour.
---@field width? number Line width in content pixels, greater than 0. Default: 2. The bounds check extends both end points by width/2 on each axis.
---@field dash_length? number Dash length in content pixels, 0 or more. Default: 0 (solid).
---@field gap_length? number Gap length in content pixels, 0 or more. Default: 0.
---@field dash_offset? number Dash offset in content pixels. Default: 0.

---These are the properties of a filled polygon.
---@class TC.GraphicsPolygon: TC.GraphicsCommon
---@field vertices TC.GraphicsPoint[] Triangle strip, at least three points, as in LuaRendering.draw_polygon. Bounds use every vertex.
---@field color TC.GraphicsColor Fill colour.

---These are the properties of an axis-aligned rectangle in display axes.
---@class TC.GraphicsRectangle: TC.GraphicsCommon
---@field left_top TC.GraphicsPoint Top-left corner.
---@field right_bottom TC.GraphicsPoint Bottom-right corner. Each coordinate must be greater than or equal to left_top.
---@field color TC.GraphicsColor Fill or outline colour.
---@field filled? boolean Default: false.
---@field width? number Outline width in content pixels when not filled, greater than 0. Default: 2. Bounds extend by width/2.

---These are the properties of a circle.
---@class TC.GraphicsCircle: TC.GraphicsCommon
---@field target TC.GraphicsPoint Centre.
---@field radius number Radius in content pixels, greater than 0.
---@field color TC.GraphicsColor Fill or outline colour.
---@field filled? boolean Default: false.
---@field width? number Outline width in content pixels when not filled, greater than 0. Default: 2. Bounds extend by width/2.

---Bounds use the exact annulus sector, not the full circle.
---@class TC.GraphicsArc: TC.GraphicsCommon
---@field target TC.GraphicsPoint Centre.
---@field min_radius number Inner radius in content pixels, 0 or more.
---@field max_radius number Outer radius in content pixels, greater than min_radius.
---@field start_angle number Start angle in radians, clockwise from the display's +x axis.
---@field angle number Sweep in radians, greater than 0 and at most 2*pi.
---@field color TC.GraphicsColor Arc colour.

---Text uses only the monitor terminal font. Each byte is one 6x9 glyph times scale, with the terminal glyph repertoire and replacement rule.
---Rich text is never parsed; bytes such as [ and ] are literal glyphs. There is no font option.
---The covered rectangle is (#text*6*scale) by (9*scale) pixels, placed by alignment and vertical_alignment, then rotated around target.
---@class TC.GraphicsText: TC.GraphicsCommon
---@field text string Literal bytes, bounded by write_bytes. An empty string is accepted.
---@field target TC.GraphicsPoint Anchor point.
---@field color TC.GraphicsColor Glyph colour.
---@field scale? number Half-step 0.5..5, as text scale. Default: 1.
---@field alignment? 'left'|'center'|'right' Horizontal anchor. Default: 'left'.
---@field vertical_alignment? 'top'|'middle'|'bottom' Vertical anchor. Default: 'top'.
---@field orientation? number Clockwise turn 0..1 around target. Default: 0.

---The sprite must be an icon path type/name of the type item, fluid, entity, recipe, technology, virtual-signal, tile, item-group, quality, space-location, asteroid-chunk or equipment.
---The path must be valid in the current game. Other paths, including file/ and utility/, cause E_RANGE.
---At x_scale = y_scale = 1 an icon covers 64x64 content pixels (one tile), centred on target, then rotated by orientation.
---@class TC.GraphicsSprite: TC.GraphicsCommon
---@field sprite string Icon path such as 'item/iron-plate' or 'virtual-signal/signal-A'.
---@field target TC.GraphicsPoint Centre.
---@field x_scale? number Horizontal scale, greater than 0. Default: 1.
---@field y_scale? number Vertical scale, greater than 0. Default: 1.
---@field tint? TC.GraphicsColor Default: white.
---@field orientation? number Clockwise turn 0..1. Default: 0.

---A light uses the engine's default light texture. Its visible glow stays within radius of target.
---@class TC.GraphicsLight: TC.GraphicsCommon
---@field target TC.GraphicsPoint Centre.
---@field radius number Visible radius in content pixels, greater than 0.
---@field color? TC.GraphicsColor Default: white.
---@field intensity? number 0..1. Default: 1.
---@field minimum_darkness? number Darkness 0..1 below which the light is not drawn. Default: 0.

---This is a copy of one object returned by get.
---It holds the type and every stored property, with defaults filled and points/colours in map form.
---@class TC.GraphicsObject
---@field type 'line'|'polygon'|'rectangle'|'circle'|'arc'|'text'|'sprite'|'light' Object type. It cannot be changed.

---Graphics draw methods share these rules:
---each creates one native object in front of all others and returns its new id;
---properties are validated completely before any change (E_ARGUMENT for shape/type, E_RANGE for domain or bounds);
---a payload above the per-call byte or entry allowance causes E_LIMIT;
---an object that would raise all monitor presentation objects above render_object_limit causes E_CAPACITY;
---the change is applied during the call and becomes visible with all other changes of the same tick;
---a later failure in the same callback does not undo it. No synchronization group or flush is involved.
---In terminal mode every draw method causes E_UNSUPPORTED.
---@param props TC.GraphicsLine Line properties.
---@return TC.GraphicsObjectId id New object id.
function Monitor.drawLine(props) end

---Draw a filled triangle-strip polygon. Shared draw rules apply.
---@param props TC.GraphicsPolygon Polygon properties.
---@return TC.GraphicsObjectId id New object id.
function Monitor.drawPolygon(props) end

---Draw a filled or outlined rectangle. Shared draw rules apply.
---@param props TC.GraphicsRectangle Rectangle properties.
---@return TC.GraphicsObjectId id New object id.
function Monitor.drawRectangle(props) end

---Draw a filled or outlined circle. Shared draw rules apply.
---@param props TC.GraphicsCircle Circle properties.
---@return TC.GraphicsObjectId id New object id.
function Monitor.drawCircle(props) end

---Draw an arc (annulus sector). Shared draw rules apply.
---@param props TC.GraphicsArc Arc properties.
---@return TC.GraphicsObjectId id New object id.
function Monitor.drawArc(props) end

---Draw terminal-font text. Shared draw rules apply.
---@param props TC.GraphicsText Text properties.
---@return TC.GraphicsObjectId id New object id.
function Monitor.drawText(props) end

---Draw a game icon. Shared draw rules apply.
---@param props TC.GraphicsSprite Sprite properties.
---@return TC.GraphicsObjectId id New object id.
function Monitor.drawSprite(props) end

---Draw a light with the default texture. Shared draw rules apply.
---@param props TC.GraphicsLight Light properties.
---@return TC.GraphicsObjectId id New object id.
function Monitor.drawLight(props) end

---Change some properties of one object.
---Only keys valid for its type are accepted; the type cannot change.
---The method validates the complete resulting object, including bounds, before any change.
---An unknown id causes E_NOT_FOUND. Draw order and id stay unchanged.
---The method returns zero values.
---@param id TC.GraphicsObjectId Existing object id.
---@param props table Partial properties for that object type, as in the draw method of that type.
function Monitor.set(id, props) end

---Read one object.
---In graphics mode, an unknown id returns nil; it is not an error.
---@param id TC.GraphicsObjectId Object id.
---@return TC.GraphicsObject|nil object Fresh copy of the type and properties, or nil.
function Monitor.get(id) end

---List every object id from back to front.
---@return TC.GraphicsObjectId[] ids Fresh dense array in draw order. Empty when there are no objects.
function Monitor.getObjects() end

---Remove one object. An unknown id causes E_NOT_FOUND.
---The id is not reused.
---The method returns zero values.
---@param id TC.GraphicsObjectId Existing object id.
function Monitor.destroy(id) end

---Move one object to the front of the draw order.
---An unknown id causes E_NOT_FOUND.
---The method returns zero values.
---@param id TC.GraphicsObjectId Existing object id.
function Monitor.bringToFront(id) end

---Move one object to the back of the draw order.
---An unknown id causes E_NOT_FOUND.
---The method returns zero values.
---@param id TC.GraphicsObjectId Existing object id.
function Monitor.moveToBack(id) end
