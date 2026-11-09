## MODIFIED Requirements

### Requirement: CC-shaped terminal methods
The monitor SHALL implement the complete terminal-method subset documented in `api/monitor.d.lua`, including cursor/blink, write, clear, scrolling, blit, colors, palettes and text scale. Color/Colour aliases SHALL behave identically. Writes SHALL clip rather than wrap automatically. These methods SHALL be available in terminal mode; graphics mode refuses them as documented by `monitor-graphics`.

#### Scenario: Write beyond the right edge
- **WHEN** a program writes text extending past the last column
- **THEN** visible text is clipped, the cursor advances by the supplied text length and no automatic line wrap occurs.

#### Scenario: Invalid blit is atomic
- **WHEN** text and color strings have different lengths or contain invalid color digits
- **THEN** the operation fails without changing cells, cursor or display revision.

#### Scenario: Terminal method in graphics mode
- **WHEN** a program calls `blit` on a graphics-mode monitor
- **THEN** the call fails with `E_UNSUPPORTED` and neither the graphics objects nor the stored terminal state change.

### Requirement: Scale and resize semantics
Text scale SHALL support half-step values from 0.5 through 5. A change in physical group geometry or text scale SHALL recompute terminal dimensions. When character dimensions change, the display SHALL clear and notify accessible registered computers with `monitor_resize`. In graphics mode, every geometry change and every mode change SHALL clear the display and notify with dimensions in the units of each mode.

#### Scenario: Larger array changes dimensions
- **WHEN** adding tiles increases the display's character dimensions
- **THEN** the new buffer is blank using the retained current colors, cursor position/blink and palette remain defined by the API contract, and resize is emitted after the new dimensions are readable.

#### Scenario: Invalid scale
- **WHEN** a scale is outside the allowed range or not a half-step
- **THEN** the monitor remains unchanged and the program receives an E_RANGE error.

#### Scenario: Mode change notification
- **WHEN** a 2×2 terminal-mode monitor at scale 1 switches to graphics mode
- **THEN** `monitor_resize` reports reason `mode`, mode `graphics`, old size 20×13 cells and new size 124×124 pixels.

### Requirement: Character-cell touch events
A valid world interaction with a valid display SHALL map to a 1-based character cell and emit `monitor_touch` to registered authorized computers. Border/outside clicks, GUI-hover input and unauthorized interaction MUST NOT create touch events. In graphics mode, the event SHALL instead report 0-based integer pixel coordinates in the content area. Each touch event SHALL state the mode of its coordinates.

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

#### Scenario: Touch on a graphics display
- **WHEN** a player activates the point 1.5 tiles right of and 0.25 tiles below the content origin of a graphics-mode display
- **THEN** the event reports mode `graphics`, x 96 and y 16, in the display's own axes for every orientation.

### Requirement: Tile and terminal dimensions with explicit units
The monitor inspector SHALL show display-local tile width × height, total connected tiles, terminal columns × rows and current text scale. Character dimensions SHALL agree with the existing terminal size contract. Cells SHALL be labelled as columns/rows, not pixels. Inspecting size SHALL NOT change scale, geometry, buffers or presentation state. A graphics-mode monitor SHALL show its mode, pixel size and object count instead of columns, rows and scale.

#### Scenario: Single and merged displays
- **WHEN** a player inspects a single tile or a valid merged rectangular display
- **THEN** the connected tile dimensions/count describe that logical rectangle and the terminal dimensions describe its current character grid.

#### Scenario: Rotated nonsquare display
- **WHEN** a nonsquare display is inspected in any cardinal orientation
- **THEN** tile width/height follow the display's local axes and terminal columns/rows remain consistent with the API, rather than swapping according to world coordinates.

#### Scenario: Text scale changes
- **WHEN** an authorized program changes text scale while the inspector is open
- **THEN** the next successful refresh shows the new scale and terminal dimensions while the physical tile dimensions/count remain unchanged.

#### Scenario: Mode changes while inspected
- **WHEN** an authorized program switches the inspected monitor to graphics mode
- **THEN** the next successful refresh shows the mode, the pixel size and the object count, and the tile dimensions stay unchanged.
