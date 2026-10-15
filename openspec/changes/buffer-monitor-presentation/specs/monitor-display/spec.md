# Monitor buffered-presentation delta

Baseline: `add-native-circuit-computers/specs/monitor-display` and the world-feedback delta in `redesign-device-experience/specs/monitor-display`. Those changes remain unarchived; no canonical monitor spec currently exists. Existing terminal, identity, power, glyph, layer and feedback requirements remain binding. The normative Lua companion is [lua-api.md](lua-api.md).

## ADDED Requirements

### Requirement: Complete rectangular displays up to six tiles per axis
Compatible monitor tiles SHALL support every complete rectangular logical display with local width and height from one through six tiles. Narrow, nonsquare and square displays SHALL use the same grouping rules at every supported text scale and cardinal orientation. Irregular or oversized walls SHALL still partition deterministically into valid rectangles.

#### Scenario: All supported rectangular dimensions
- **WHEN** a compatible complete W×H wall has each local dimension between one and six, including 1×1, 1×6, 3×6, 6×3, 6×1 and 6×6
- **THEN** it can form one logical display within the published world capacities, rather than being split at the old four-tile boundary
- **AND** all existing half-step text scales from 0.5 through 5 remain supported.

#### Scenario: Oversized or irregular wall
- **WHEN** a wall exceeds six tiles on an axis or contains holes or an L-shaped arrangement
- **THEN** it partitions into nonoverlapping complete rectangles with neither axis above six, preserving the established identity and ordering rules.

### Requirement: Geometry-driven buffering
Buffering SHALL derive cell layout, allocation, clipping, preparation progress and admission from each display's actual width, height, scale and orientation. Smaller screens SHALL NOT require a padded maximum-size buffer. A supported nonsquare shape SHALL NOT be rejected because buffering assumes square screens or equal dimensions across a synchronization group.

#### Scenario: Mixed screen geometries
- **WHEN** a selected group contains 1×1, 3×6 and 6×6 displays whose actual combined cells fit the published group limit
- **THEN** each prepares its own complete image with correct row strides, cursor, palette and orientation
- **AND** the group publishes together without stretching, square padding or equal-resolution requirements.

#### Scenario: Maximum supported resolution
- **WHEN** a 6×6 display uses scale 0.5
- **THEN** its 126×84 grid of 10,584 cells is supported by automatic singleton buffering, staging, retirement and whole-frame publication.

### Requirement: Automatic snapshot presentation
Monitor drawing SHALL buffer presentation automatically without requiring a flush or frame-control call. Successful operations SHALL update the shared model synchronously. Automatic snapshots SHALL be taken after synchronized callback dispatch, never midway through a callback. The previous complete visible image SHALL remain until its replacement is ready, except for power, geometry or identity invalidation.

#### Scenario: Existing program draws without a new API
- **WHEN** an existing callback clears and redraws a monitor using existing terminal methods
- **THEN** subsequent calls observe the updated model immediately
- **AND** the world transitions from the previous image to a prepared snapshot without a renderer-generated row sweep.

#### Scenario: Later call fails
- **WHEN** a callback makes successful monitor changes and then encounters a rejected call or faults
- **THEN** its earlier successful model changes remain eligible for automatic presentation
- **AND** neither the rejected operation nor callback failure introduces a model rollback transaction.

### Requirement: Coherent image publication
Each published image SHALL contain cells, palette, cursor, scale and geometry from one fixed snapshot. A monitor SHALL NOT expose a partially prepared replacement or falsely acknowledge a mixed-revision image as current. Cursor blink SHALL NOT reveal staged cursor objects.

#### Scenario: Model changes while a frame is prepared
- **WHEN** new writes or palette changes occur while a large snapshot is being prepared over multiple ticks
- **THEN** the prepared snapshot remains unchanged and completes independently
- **AND** newer accepted changes remain eligible for a later complete snapshot.

#### Scenario: Initial maximum-resolution draw
- **WHEN** a new maximum-resolution screen requires several ticks of preparation
- **THEN** no partially populated new frame becomes visible before publication.

### Requirement: Synchronized group update rounds
An explicitly selected monitor group SHALL wait for a successful mutating terminal operation on every member after registration or the preceding snapshot seal. Once all members participate, their current models SHALL be captured at one post-dispatch boundary. All prepared members SHALL publish in the same simulation tick with one group sequence. Waiting SHALL NOT time out into partial publication.

#### Scenario: Members are updated in different callbacks
- **WHEN** one selected monitor receives updates but another has not participated in the next round
- **THEN** the group's prior visible images remain unchanged and status reports waiting
- **AND** after the remaining member participates, the current complete snapshot vector becomes eligible for preparation.

#### Scenario: Different preparation costs
- **WHEN** one selected member finishes preparation before another
- **THEN** neither replacement becomes visible until the whole group can publish together.

#### Scenario: No-op member participation
- **WHEN** a program successfully repeats a mutating terminal operation without changing visible content
- **THEN** that member can satisfy round participation without forcing unnecessary sprite reconstruction.

### Requirement: Bounded buffering and admission
Snapshot retention, preparation, retirement, native objects, group size and whole-group commit work SHALL have published enforceable limits. Unsupported group registration SHALL fail before replacing the prior selection. Exhausted preparation or commit credits SHALL defer the entire remaining operation without partially publishing a frame. Guest and aggregate safety limits SHALL NOT be raised to conceal an infeasible commit.

#### Scenario: Supported large group
- **WHEN** four powered 6×6 scale-1 logical screens totaling 10,584 cells are selected within the published envelope
- **THEN** the group is supported without raising callback or shared host/maintenance ceilings
- **AND** its entire ready publication fits the declared native-object and work limits.

#### Scenario: Commit credits are insufficient
- **WHEN** the next ready group's whole commit cannot be admitted in the current tick
- **THEN** all its old frames stay visible, prepared replacements stay hidden, and publication is retried fairly later.

#### Scenario: Registered group grows beyond capacity
- **WHEN** a valid scale or geometry change makes the selected group's combined cells exceed its limit
- **THEN** ordinary model resize semantics are preserved
- **AND** group publication is blocked with an observable E_CAPACITY diagnostic until it fits or is reconfigured, never silently split.

### Requirement: Bounded progress without stale-frame starvation
The presenter SHALL retain bounded pending updates, coalesce superseded pending snapshots, and finish an admitted snapshot without repeatedly restarting for newer writes. Unrelated eligible monitors/groups SHALL receive deterministic fair service. Within the published stable-world envelope, quiescent accepted state SHALL reach presentation within the declared latency target.

#### Scenario: Continuous updates
- **WHEN** one producer keeps changing a screen faster than preparation completes
- **THEN** complete images still publish and an unrelated eligible screen is not starved
- **AND** pending retention does not grow with the update history.

#### Scenario: Producer becomes idle
- **WHEN** changes stop and selected groups have completed participation with stable power, geometry and authority
- **THEN** final visible contents match the latest accepted model within the supported latency envelope.

### Requirement: Fair demand-driven maintenance headroom
Publication headroom SHALL be requested only through bounded trusted demand and frozen per actual tick. Same-tick entry or load SHALL NOT renew credits or alter that frozen reservation. A baseline non-render service opportunity SHALL occur between boosted reservations, and topology initialization SHALL make admitted resumable progress rather than require one large atomic setup charge.

#### Scenario: Continuous ready-publication demand
- **WHEN** large publication requests remain ready across consecutive actual ticks
- **THEN** boosted reservations cannot eliminate baseline maintenance-service opportunities
- **AND** topology, notifications, cleanup and a running neighboring computer retain forward progress within unchanged aggregate ceilings.

#### Scenario: Reload during topology initialization
- **WHEN** a save retains a partial topology initializer, pending render demand and spent maintenance credits
- **THEN** reload preserves the next initialization step, frozen same-tick reservation and spent credits without initialization work on load.

### Requirement: Lifecycle-safe buffered state
Save/load SHALL preserve complete visible state, accepted model state, pending snapshots, group selections, paid progress and spent same-tick credits without executing guest code on load. Power loss SHALL hide affected output without clearing its model. Geometry/identity invalidation SHALL prevent stale publication and unsafe touch mapping; removal SHALL retire all owned staged and visible objects.

#### Scenario: Cold load during preparation
- **WHEN** the game is saved with an old visible frame, a partially prepared hidden frame and newer pending writes
- **THEN** a separate process resumes those states without exposing staged objects, replaying the producer or renewing credits.

#### Scenario: Resize during preparation
- **WHEN** scale, topology or rotation invalidates a prepared frame
- **THEN** that frame cannot publish with stale geometry
- **AND** touches are ignored while visible and authoritative grid geometry disagree, rather than reported against the wrong image.

#### Scenario: Power outage
- **WHEN** one group member loses power
- **THEN** that display hides without erasing model state and no replacement group frame partially publishes
- **AND** restoration resumes or rebuilds only valid complete frames without a fabricated resize.

### Requirement: Honest compatibility and visual acceptance
Documentation SHALL distinguish coherent snapshots, same-tick group publication and application-level frame completion. Existing terminal signatures and aliases SHALL remain available. Claims of tear-free native appearance SHALL require graphical-client evidence; headless model/visibility assertions SHALL be identified separately.

#### Scenario: Drawing intentionally spans callbacks
- **WHEN** a script draws four rows per callback and only later completes its plot
- **THEN** automatic buffering does not claim to infer a hidden application-frame boundary
- **AND** the example documentation explains its producer pacing separately from renderer tearing.

#### Scenario: World feedback during staging
- **WHEN** screens are selected, wired, marked for deconstruction or touched while hidden frames are prepared and published
- **THEN** existing native feedback layers, Ctrl-click interaction and character-coordinate behavior remain valid.

### Requirement: Grouping-policy upgrade reconciliation
An upgrade increasing the merged-display limit SHALL reevaluate existing walls during admitted synchronized work even when no tile changes. Normal surviving-anchor, absorbed-identity, settings-inheritance and resize rules SHALL apply. Changed character dimensions SHALL clear content as documented; ordinary load SHALL neither mutate storage nor execute guest code to force regrouping.

#### Scenario: Existing six-by-six wall under an older grouping policy
- **WHEN** a saved compatible 6×6 wall partitioned by the old 4×4 limit is upgraded without moving, adding or removing tiles
- **THEN** it is reevaluated and can become one 6×6 logical display under the new policy
- **AND** surviving identity/settings, absorbed-name detachment and dimension-change clearing/resize follow the established contract without requiring a player to rebuild the wall.
