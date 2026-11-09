## MODIFIED Requirements

### Requirement: Explicit compatibility and glyph policy
The companion Lua contract SHALL state supported glyphs, byte/cell indexing, geometry and deliberate CC:Tweaked differences. The mod MUST NOT claim CraftOS, CC event-loop or arbitrary Unicode-terminal compatibility from monitor-method compatibility alone.

#### Scenario: Unsupported text byte
- **WHEN** a string contains a byte outside the supported glyph repertoire
- **THEN** the documented replacement-glyph rule is applied consistently without corrupting blit alignment or interpreting text as Factorio rich text.

#### Scenario: Rich-text syntax in guest text
- **WHEN** a program writes bytes such as `[color=red]`, `[img=item/iron-plate]` or `[/color]`
- **THEN** every byte is displayed as its own literal glyph cell
- **AND** no colour, icon or other rich-text effect appears, even though rows are presented as native text.

### Requirement: Bounded sparse animation presentation
The presenter SHALL retain bounded dirty-row metadata and MAY reuse unchanged native rows without preparing or retiring every grid row. Damage acknowledgement SHALL NOT consume later writes, coalesced pending changes or a newer full-invalidation epoch. Full clear, scroll, palette, geometry and untracked legacy state SHALL retain a conservative full-frame path. Existing snapshot coherence, synchronous model visibility, admission, ownership, retirement and aggregate caps remain binding.

#### Scenario: Complete bounded chart frames at two-tick cadence
- **WHEN** the maintained smooth-sine-chart example updates all four selected screens every two actual simulation ticks within the documented scale-2 6×6 or mixed-layout test envelope and configured default guest budgets
- **THEN** headless acceptance measures at least 360 complete publication intervals per layout and engine mode, each at most two simulation ticks apart after warmup
- **AND** actual native fronts agree with one shared phase, including after ordinary cold reload and periodic rediscovery
- **AND** paused fixture snapshot-writing boundaries are separated from uninterrupted cadence windows; neither cadence nor scheduler profiles claim graphical-client FPS.

#### Scenario: A large old frame has accumulated later writes
- **WHEN** more model writes occur after a large snapshot is sealed and before it publishes
- **THEN** its prepaid acknowledgement consumes only matching rows from the same invalidation epoch and retains later changes for the next frame
- **AND** the presenter does not increase native-object, preparation-cell, commit or maintenance caps to conceal the cost.

### Requirement: Coherent image publication
Each published image SHALL contain cells, palette, cursor, scale and geometry from one fixed snapshot. A monitor SHALL NOT expose a partially prepared replacement or falsely acknowledge a mixed-revision image as current. Cursor blink SHALL NOT reveal staged cursor objects.

#### Scenario: Model changes while a frame is prepared
- **WHEN** new writes or palette changes occur while a large snapshot is being prepared over multiple ticks
- **THEN** the prepared snapshot remains unchanged and completes independently
- **AND** newer accepted changes remain eligible for a later complete snapshot.

#### Scenario: Initial maximum-resolution draw
- **WHEN** a new maximum-resolution screen requires several ticks of preparation
- **THEN** no partially populated new frame becomes visible before publication.

#### Scenario: Changed cells reuse their visible objects
- **WHEN** a prepared frame changes the glyph or colours of a cell whose row already shows valid native objects
- **THEN** those objects take the new text, colours and background runs in the publication tick, together with all other changes of the frame
- **AND** a frame that is deferred, cancelled or refused before publication changes no visible object and owns no native object.

## ADDED Requirements

### Requirement: Row text presentation
A visible terminal row SHALL be drawn with at most one native glyph-text object and one native background-text object. The glyph object SHALL use the mod's 6×9 terminal font, with each guest byte mapped to its own private-use code point. Unchanged rows SHALL keep their objects without native writes. Object count SHALL grow with rows, not with cells or colour runs.

#### Scenario: Maximum grid with few colour runs
- **WHEN** a 6×6 display at scale 0.5 shows a 126×84 chart whose rows each hold three or fewer foreground and background runs
- **THEN** its visible front holds at most 84 glyph-text objects, 84 background-text objects, one panel and one cursor
- **AND** the cell content, colours and cursor match the model exactly.

#### Scenario: One cell changes
- **WHEN** a program changes one cell and the frame publishes
- **THEN** only that cell's row receives native writes
- **AND** every other row keeps its objects and makes no native call.

### Requirement: Pixel-faithful row text
Row text SHALL reproduce the existing 6×9 glyph pixels at every supported text scale and cardinal orientation. Glyphs and their backgrounds SHALL stay aligned with each other at every zoom level. The native deconstruction marker SHALL remain visible on a marked display. Selection boxes and wires MAY draw below row text inside the content area.

#### Scenario: Compare with the sprite presentation
- **WHEN** the same model is captured with the full client at zoom 0.5, 1, 2 and 4, in base and Space Age, in all four orientations
- **THEN** glyph and background pixels align with each other within one screen pixel at every zoom
- **AND** the background is drawn as text so both layers share the engine's text offset, and the remaining offset against the bezel (about 6 screen pixels down at every zoom) is documented.

#### Scenario: Mark a row-text display for deconstruction
- **WHEN** the player marks a populated row-text monitor for deconstruction
- **THEN** its row text is hidden while any of its tiles is marked, and the native red deconstruction marker is visible
- **AND** cancelling the mark shows the same content again without guest code, and the model and its revision are unchanged.

#### Scenario: Non-English locale
- **WHEN** the client locale is `ru`, `ja` or `zh-CN`
- **THEN** the terminal font loads and the monitor shows the same glyph pixels as in `en`.

### Requirement: Row model upgrade
A save that holds per-cell monitor models or per-cell fronts SHALL upgrade in synchronized work after configuration change. The upgrade SHALL preserve cells, colours, palette, cursor, scale, identity and geometry, run no guest code and leave no old native objects behind.

#### Scenario: Upgrade a populated wall
- **WHEN** a save from the previous release contains a populated 6×6 display, a front and a pending frame
- **THEN** after the upgrade the display shows the same content as row text
- **AND** every old per-cell sprite is destroyed, the pending changes still publish, and the next settled ticks do no presentation work.

#### Scenario: Unsupported retained shape
- **WHEN** a saved monitor model has neither the old cell shape nor the new row shape
- **THEN** the display stays inert with a diagnostic instead of being treated as blank.
