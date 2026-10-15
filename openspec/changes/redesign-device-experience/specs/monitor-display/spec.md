# Monitor world-feedback delta

Baseline: corresponding capability in `add-native-circuit-computers`; group geometry/identities, character-cell touch, palette/glyph rules, durable display state and bounded rendering remain binding.

## ADDED Requirements

### Requirement: Visible native deconstruction feedback
Each monitor tile marked for deconstruction SHALL visibly show the native red deconstruction marker above its displayed content and decoration. Marking MUST NOT be represented only by a custom fault symbol, a hidden helper state or a console message. Feedback SHALL work on powered, unpowered and actively redrawing displays.

#### Scenario: Mark a running display
- **WHEN** the player marks a powered monitor displaying text and changing colors
- **THEN** the native red X remains legible while the tile awaits removal, regardless of continuing redraws or cursor blinking.

#### Scenario: Mark part of a merged display
- **WHEN** only some tiles in a merged monitor are marked
- **THEN** each marked tile has unambiguous native removal feedback and unmarked tiles do not falsely appear marked.

### Requirement: Reversible marking without display loss
Marking or cancelling deconstruction SHALL preserve the display's committed cells, palette, cursor, scale and grouping until an actual topology change. Cancellation SHALL remove the marker normally and restore any presentation-only suppression. Rendering MUST NOT erase model state just to reveal an engine overlay.

#### Scenario: Cancel removal
- **WHEN** the player cancels deconstruction before the monitor is removed
- **THEN** the same display state is still available and visible, without an artificial resize, identity replacement or reset.

#### Scenario: Robot removes a marked tile
- **WHEN** a robot actually removes a tile from a marked array
- **THEN** ordinary split/detach/resize behavior runs once, removed content has no lingering render objects, and remaining tiles retain valid geometry.

### Requirement: Layered world readability and touch
Monitor content and decorative/status artwork SHALL not obscure native selection outlines, wiring feedback or deconstruction markers. A visible connector SHALL sit in the bezel rather than consuming content cells. Existing character-coordinate touch behavior SHALL remain unchanged in every cardinal orientation.

#### Scenario: Select and wire a display
- **WHEN** the player hovers or wires a populated monitor at normal zoom
- **THEN** its selection and connector remain legible while displayed content remains readable.

#### Scenario: Interact with a non-anchor tile
- **WHEN** an authorized player touches a valid cell on a non-anchor tile after the visual redesign
- **THEN** the event retains the existing logical-display identity and correct 1-based combined-screen coordinates.
