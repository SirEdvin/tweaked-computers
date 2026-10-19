# Monitor Display

## Purpose

Provide flat, in-world color terminal displays assembled from adjacent monitor tiles, with familiar CC:Tweaked-style drawing methods and deterministic interaction events.

## ADDED Requirements

### Requirement: Rectangular monitor groups
Adjacent compatible 1×1 tiles SHALL combine into rectangular displays subject to published limits. Compatibility SHALL require the same force, surface and orientation. Holes, diagonal contact and L-shapes MUST NOT become irregular display surfaces.

#### Scenario: Complete rectangle
- **WHEN** compatible adjacent tiles complete a valid rectangle within the supported dimensions
- **THEN** they expose one display with a single cursor, palette, text scale and character buffer.

#### Scenario: Nonrectangular placement
- **WHEN** a tile arrangement cannot be merged into one complete rectangle
- **THEN** it remains a deterministic partition of valid rectangular groups with every tile belonging to exactly one group.

### Requirement: Deterministic merge and split identity
Grouping and identity changes SHALL be deterministic for the same ordered world events. A group containing its retained anchor SHALL retain its identity; other split groups SHALL receive new identities. Absorbed identities SHALL detach rather than silently retarget old wrappers.

#### Scenario: Remove a tile from an existing display
- **WHEN** removing a tile splits the old display
- **THEN** all resulting groups have valid nonoverlapping geometry and unambiguous identities
- **AND** affected computers receive the required detach/attach/resize notifications.

### Requirement: CC-shaped terminal methods
The monitor SHALL implement the complete terminal-method subset documented in `lua-api.md`, including cursor/blink, write, clear, scrolling, blit, colors, palettes and text scale. Color/Colour aliases SHALL behave identically. Writes SHALL clip rather than wrap automatically.

#### Scenario: Write beyond the right edge
- **WHEN** a program writes text extending past the last column
- **THEN** visible text is clipped, the cursor advances by the supplied text length and no automatic line wrap occurs.

#### Scenario: Invalid blit is atomic
- **WHEN** text and color strings have different lengths or contain invalid color digits
- **THEN** the operation fails without changing cells, cursor or display revision.

### Requirement: Scale and resize semantics
Text scale SHALL support half-step values from 0.5 through 5. A change in physical group geometry or text scale SHALL recompute terminal dimensions. When character dimensions change, the display SHALL clear and notify accessible registered computers with `monitor_resize`.

#### Scenario: Larger array changes dimensions
- **WHEN** adding tiles increases the display's character dimensions
- **THEN** the new buffer is blank using the retained current colors, cursor position/blink and palette remain defined by the API contract, and resize is emitted after the new dimensions are readable.

#### Scenario: Invalid scale
- **WHEN** a scale is outside the allowed range or not a half-step
- **THEN** the monitor remains unchanged and the program receives an E_RANGE error.

### Requirement: Character-cell touch events
A valid world interaction with a powered display SHALL map to a 1-based character cell and emit `monitor_touch` to registered authorized computers. Border/outside clicks, GUI-hover input and unauthorized interaction MUST NOT create touch events.

The shared Ctrl-click input SHALL pass through native game actions and SHALL NOT
block reuse of held modifiers. Lua context rejection MUST NOT prevent native
inventory transfers or subsequent Ctrl shortcuts before Ctrl is released.

#### Scenario: Native Ctrl behavior remains available
- **WHEN** a player Ctrl-clicks vanilla containers or inventory slots, repeats the gesture while holding Ctrl, or uses another Ctrl shortcut before releasing it
- **THEN** the native actions remain available without opening a mod workspace or creating a monitor touch.

#### Scenario: Touch on a merged display
- **WHEN** a player activates a cell on a non-anchor tile
- **THEN** the event identifies the logical display, the correct combined-screen coordinates, player and channel
- **AND** duplicated physical wiring does not duplicate that subscription's event.

### Requirement: Shared durable display state
Authorized computers SHALL share one committed display state. Save/load SHALL preserve contents, colors, palette, cursor and scale. Writer stop or disconnect SHALL not clear the display; loss of display power SHALL hide output while retaining its model.

#### Scenario: Writer stops after drawing
- **WHEN** the last drawing computer stops
- **THEN** the powered monitor continues displaying its last committed image.

### Requirement: Bounded rendering without hidden loss
Display dimensions, cells, text payloads and rendering work SHALL be bounded and queryable. Accepted model updates SHALL be presented within the published supported latency envelope. Rendering backlog MUST NOT silently lose the most recent committed revision.

#### Scenario: Rapid updates followed by idle
- **WHEN** several valid updates arrive before rendering catches up
- **THEN** the final displayed cells match the latest complete committed model, not a falsely current mixed-revision sweep.

### Requirement: Explicit compatibility and glyph policy
The companion Lua contract SHALL state supported glyphs, byte/cell indexing, geometry and deliberate CC:Tweaked differences. The mod MUST NOT claim CraftOS, CC event-loop or arbitrary Unicode-terminal compatibility from monitor-method compatibility alone.

#### Scenario: Unsupported text byte
- **WHEN** a string contains a byte outside the supported glyph repertoire
- **THEN** the documented replacement-glyph rule is applied consistently without corrupting blit alignment or interpreting text as Factorio rich text.
