# Spec Delta

## ADDED Requirements

### Requirement: Logical display identity in the inspector
Opening any member tile SHALL inspect its current logical display and show the same copyable API name returned by peripheral discovery. A physical tile's internal identity SHALL NOT be substituted for the logical name. Uncommitted regrouping SHALL be explicitly pending rather than exposing guessed identity or geometry.

#### Scenario: Open a non-anchor tile
- **WHEN** a player normally opens a non-anchor member of a merged monitor
- **THEN** the inspector shows the same logical API name and dimensions as opening its anchor, without requiring the anchor to be within the player's reach.

#### Scenario: Topology is being reconciled
- **WHEN** monitor grouping has not yet committed after a topology change
- **THEN** the inspector labels the logical identity/dimensions as pending and does not offer an obsolete name as current for copying.

### Requirement: Tile and terminal dimensions with explicit units
The monitor inspector SHALL show display-local tile width × height, total connected tiles, terminal columns × rows and current text scale. Character dimensions SHALL agree with the existing terminal size contract. Cells SHALL be labelled as columns/rows, not pixels. Inspecting size SHALL NOT change scale, geometry, buffers or presentation state.

#### Scenario: Single and merged displays
- **WHEN** a player inspects a single tile or a valid merged rectangular display
- **THEN** the connected tile dimensions/count describe that logical rectangle and the terminal dimensions describe its current character grid.

#### Scenario: Rotated nonsquare display
- **WHEN** a nonsquare display is inspected in any cardinal orientation
- **THEN** tile width/height follow the display's local axes and terminal columns/rows remain consistent with the API, rather than swapping according to world coordinates.

#### Scenario: Text scale changes
- **WHEN** an authorized program changes text scale while the inspector is open
- **THEN** the next successful refresh shows the new scale and terminal dimensions while the physical tile dimensions/count remain unchanged.

### Requirement: Safe monitor inspector updates
The inspector SHALL follow the originally selected physical tile while revalidating its logical-group mapping. Split or merge changes SHALL refresh the displayed name and dimensions together after commit. Removal or replacement of the selected tile SHALL invalidate the session. Powered-off monitors SHALL retain inspectable committed geometry without unblanking or modifying their saved display model.

#### Scenario: Selected tile survives a split
- **WHEN** another tile is removed and the selected tile belongs to a new resulting rectangle
- **THEN** the inspector resolves that tile's current logical display and presents its identity and sizes coherently, including an identity-change indication when needed.

#### Scenario: Selected tile is replaced
- **WHEN** the selected tile is removed and another occupies its coordinates
- **THEN** the old inspector becomes unavailable rather than attaching itself to the replacement.

#### Scenario: Inspect an unpowered monitor
- **WHEN** an authorized player opens a monitor whose power is off but committed group data is valid
- **THEN** its name and committed tile/terminal dimensions remain readable with an unpowered label, while the world display remains blank and its model is unchanged.
