## Purpose

Lets programs draw native Factorio graphics (lines, shapes, text, icons and lights) inside a monitor's content area, as retained objects addressed by monitor pixel coordinates.

## ADDED Requirements

### Requirement: Monitor display modes
Each logical monitor SHALL have the mode `terminal` or `graphics`, with `terminal` as the default. `setMode(mode)` SHALL change it and `getMode()` SHALL read it. A change to another mode SHALL clear all terminal and graphics content and queue `monitor_resize` with reason `mode`. Setting the current mode SHALL change nothing and SHALL count as a successful mutating call.

#### Scenario: Switch a populated terminal to graphics
- **WHEN** a program calls `m.setMode('graphics')` on a monitor that shows text
- **THEN** the text disappears in the same tick, `m.getMode()` returns `graphics` and `m.getSize()` returns pixel dimensions
- **AND** each registered computer receives one `monitor_resize` with reason `mode`, the old cell dimensions and the new pixel dimensions.

#### Scenario: Set the current mode again
- **WHEN** a program calls `m.setMode('graphics')` on a monitor that is already in graphics mode
- **THEN** its objects, ids and order stay unchanged and no resize is queued.

#### Scenario: Unknown mode
- **WHEN** a program calls `m.setMode('pixels')`
- **THEN** the call fails with `E_RANGE` and the monitor is unchanged.

### Requirement: Monitor pixel coordinates
In graphics mode, positions and sizes SHALL be monitor pixels at 64 per tile. The origin SHALL be the top-left corner of the content area, which lies two pixels inside the bezel. X SHALL point right and y down along the display's own axes in every cardinal orientation. `getSize()` SHALL return the content width `64*W-4` and height `64*H-4` for a W×H tile display.

#### Scenario: Rotated display
- **WHEN** the same program draws a rectangle at `{0,0}`–`{20,10}` on a north-facing and an east-facing 2×1 display
- **THEN** on both displays the rectangle appears in the display's own top-left corner with the same proportions.

#### Scenario: Size of a merged display
- **WHEN** a 3×2 tile display is in graphics mode
- **THEN** `getSize()` returns `188, 124`.

### Requirement: Retained graphics objects
Each draw method SHALL create one native object and return a positive integer id. The id SHALL be unique for that logical display and SHALL never be reused, also after `clear()`. `set(id, props)` SHALL change the given properties, and `destroy(id)` SHALL remove the object. `get(id)` SHALL return a copy of its type and properties, or nil when the id does not exist. `set`, `destroy`, `bringToFront` and `moveToBack` SHALL fail with `E_NOT_FOUND` for an unknown id.

#### Scenario: Animate a line
- **WHEN** a program keeps an id from `drawLine` and later calls `set(id, {to={100,40}})`
- **THEN** the same native object moves its end point and no other object is created.

#### Scenario: Read back an object
- **WHEN** a program calls `get(id)` for an existing circle
- **THEN** it receives a fresh table with `type='circle'` and every stored property
- **AND** changing that table does not change the object.

#### Scenario: Id after clear
- **WHEN** a program clears the display and draws a new object
- **THEN** the new id differs from every id returned before the clear, and the old ids return nil from `get`.

### Requirement: Content-area bounds without clipping
A draw or set call SHALL fail with `E_RANGE` and change nothing when the object's covered area would leave the content area. The covered area SHALL include stroke width, radius, arc sector, text extent, sprite size, light radius and rotation. The host SHALL NOT clip or clamp geometry.

#### Scenario: Line partly outside
- **WHEN** a program draws a line from `{10,10}` to `{getSize()+5, 10}`
- **THEN** the call fails with `E_RANGE` and no object is created.

#### Scenario: Move an object outside
- **WHEN** `set` would move an existing rectangle partly past the right edge
- **THEN** the call fails with `E_RANGE` and the rectangle keeps all its previous properties.

#### Scenario: Arc near an edge
- **WHEN** an arc's annulus sector fits the area but its full circle would not
- **THEN** the arc is accepted.

### Requirement: Supported graphics primitives
Graphics mode SHALL provide line, polygon, rectangle, circle, arc, text, sprite and light objects with the properties listed in `api/monitor.d.lua`. Other native properties (surface, entity targets, players, forces, time to live, render mode and draw-on-ground) SHALL be refused with `E_ARGUMENT`. Colours SHALL be colour tables with channels in 0..1, and alpha SHALL default to 1.

#### Scenario: Unsupported property
- **WHEN** a program passes `time_to_live=60` or `players={1}` to a draw method
- **THEN** the call fails with `E_ARGUMENT` and no object is created.

#### Scenario: Colour out of range
- **WHEN** a colour has a channel of 255 or a combined `colors.*` mask is given as colour
- **THEN** the call fails with `E_RANGE` or `E_ARGUMENT` respectively.

### Requirement: Terminal-font graphics text
Graphics text SHALL use only the mod terminal font, with an exact size of `6*scale` by `9*scale` pixels per byte. Each byte SHALL appear as its own glyph, as on the terminal. Rich text SHALL NOT be parsed. Alignment, vertical alignment and orientation SHALL be included in the bounds check.

#### Scenario: Rich-text syntax
- **WHEN** a program draws the text `[item=iron-plate]`
- **THEN** the bytes appear as literal glyphs and no icon appears.

#### Scenario: Exact fit
- **WHEN** a program draws ten bytes at scale 2, left aligned at x=0, on a display with content width 120
- **THEN** the text is accepted, because it covers exactly 120 pixels.

### Requirement: Icon sprites and default lights
Sprites SHALL accept only game icon paths of the types `item`, `fluid`, `entity`, `recipe`, `technology`, `virtual-signal`, `tile`, `item-group`, `quality`, `space-location`, `asteroid-chunk` and `equipment`, and only when the path is valid in the current game. Lights SHALL use the engine's default light texture, sized by a radius in pixels.

#### Scenario: File or utility sprite
- **WHEN** a program draws the sprite `file/__base__/graphics/icons/iron-plate.png` or `utility/danger_icon`
- **THEN** the call fails with `E_RANGE` and no object is created.

#### Scenario: Unknown item
- **WHEN** a program draws `item/no-such-item`
- **THEN** the call fails with `E_RANGE`.

#### Scenario: Light radius
- **WHEN** a program draws a light with radius 40 at the centre of a 2×2 display
- **THEN** the light is accepted and its visible glow stays inside the 80×80-pixel square around its centre.

### Requirement: Graphics draw order
Objects SHALL be drawn back to front in creation order. `bringToFront(id)` and `moveToBack(id)` SHALL move one object to the end or start of that order. `getObjects()` SHALL return all ids back to front. The order SHALL apply across all object types.

#### Scenario: Overlapping shapes
- **WHEN** a program draws a filled rectangle, then an icon sprite over it, then calls `moveToBack` on the sprite
- **THEN** the rectangle hides the overlapping part of the sprite, and `getObjects()` lists the sprite first.

### Requirement: Immediate graphics publication
A successful graphics call SHALL change the native object during the call. All changes made in one tick SHALL become visible together. A later failure SHALL NOT undo earlier successful calls. A graphics-mode monitor SHALL NOT join a monitor synchronization group.

#### Scenario: Several calls in one callback
- **WHEN** a callback moves twenty lines and then fails with an error
- **THEN** all twenty moves appear in the same rendered frame and remain applied.

#### Scenario: Select a graphics monitor for synchronization
- **WHEN** a program passes a graphics-mode monitor to `peripheral.setMonitorSyncGroup`
- **THEN** the call fails with `E_UNSUPPORTED` and the previous selection is unchanged.

#### Scenario: Switch a group member to graphics
- **WHEN** a member of an active synchronization group is switched to graphics mode
- **THEN** that monitor leaves the group and the remaining members continue their rounds without it.

### Requirement: Mode-specific methods
In graphics mode, terminal drawing, cursor, colour, palette and text-scale methods SHALL fail with `E_UNSUPPORTED`. In terminal mode, graphics methods SHALL fail with `E_UNSUPPORTED`. `getMode`, `setMode`, `getSize`, `clear`, `getLimits` and `isColor` SHALL work in both modes; in graphics mode `clear` destroys every graphics object.

#### Scenario: Write in graphics mode
- **WHEN** a program calls `m.write('x')` or `m.setTextScale(2)` on a graphics-mode monitor
- **THEN** the call fails with `E_UNSUPPORTED` and nothing changes.

#### Scenario: Clear in graphics mode
- **WHEN** a program calls `m.clear()` on a graphics-mode monitor with objects
- **THEN** every object disappears in the same tick and `getObjects()` returns an empty array.

### Requirement: Graphics object capacity
Graphics objects SHALL count, with all other monitor presentation objects, against the existing aggregate `render_object_limit`. A call that would exceed it SHALL fail with `E_CAPACITY` and change nothing. Graphics calls SHALL use the existing per-call payload and work allowances. No per-monitor object limit SHALL be added.

#### Scenario: Aggregate limit reached
- **WHEN** a draw call would raise the number of monitor presentation objects above `render_object_limit`
- **THEN** it fails with `E_CAPACITY` and existing objects stay unchanged
- **AND** after the program destroys objects, new draw calls succeed again.

#### Scenario: Large polygon
- **WHEN** a polygon's vertex list exceeds the per-call entry allowance
- **THEN** the call fails with `E_LIMIT` before any native object is created.

### Requirement: Durable graphics state
Save and load SHALL preserve the mode, objects, properties, ids, the next id and the draw order. Power changes and writer stop SHALL NOT change graphics content. Changing the tile geometry SHALL remove all graphics objects and queue `monitor_resize` in pixels with reason `tiles`. Removing a display SHALL destroy all of its objects.

#### Scenario: Cold reload
- **WHEN** a save with a graphics-mode monitor holding 500 objects loads in a separate process
- **THEN** the same objects are visible, `getObjects()` returns the same ids in the same order and the next draw continues the id sequence.

#### Scenario: Add a tile
- **WHEN** a tile is added to a graphics-mode display
- **THEN** its objects are removed, it stays in graphics mode and registered computers receive `monitor_resize` with the old and new pixel sizes.

#### Scenario: Remove the display
- **WHEN** every tile of a graphics-mode display is mined
- **THEN** no native object of that display remains.

### Requirement: Mode inheritance and settings transfer
Merge, split, settings paste and blueprints SHALL carry the mode in the same way as text scale. A transferred mode that differs from the target's mode SHALL clear the target and queue `monitor_resize` with reason `mode`. Saves without a stored mode SHALL load as terminal mode.

#### Scenario: Paste graphics settings onto a terminal
- **WHEN** a player pastes settings from a graphics-mode monitor onto a terminal-mode monitor
- **THEN** the target switches to graphics mode, its text is cleared and its computers receive one `monitor_resize` with reason `mode`.

#### Scenario: Upgrade an old save
- **WHEN** a save made before graphics mode loads
- **THEN** every monitor is in terminal mode with its content unchanged.

### Requirement: Native feedback above graphics
Selection boxes, wires and the native deconstruction marker SHALL remain visible above graphics objects. Marking or cancelling deconstruction SHALL NOT remove graphics objects or change their ids.

#### Scenario: Mark a busy graphics display
- **WHEN** a player marks a graphics-mode display that shows filled shapes, text and sprites
- **THEN** the red deconstruction marker is visible above them
- **AND** after the mark is cancelled, `getObjects()` returns the same ids.

### Requirement: Graphics display inspection
The monitor inspector SHALL show the mode. In graphics mode it SHALL show the pixel size and the number of graphics objects instead of columns, rows and text scale. Inspection SHALL NOT change the display.

#### Scenario: Inspect a graphics monitor
- **WHEN** a player opens a 2×2 graphics-mode monitor with 12 objects
- **THEN** the inspector shows mode graphics, 124 × 124 pixels and 12 objects.
