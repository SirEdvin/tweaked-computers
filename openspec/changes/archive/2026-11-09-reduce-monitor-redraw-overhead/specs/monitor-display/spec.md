## MODIFIED Requirements

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
- **WHEN** a prepared frame changes the glyph or colors of a cell that already shows a valid object
- **THEN** that object takes the new glyph or color in the publication tick, together with all other changes of the frame
- **AND** a frame that is deferred, cancelled or refused before publication changes no visible object.
