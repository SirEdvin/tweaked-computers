# monitor-display Specification

## Purpose

Provide flat, in-world color terminal displays assembled from adjacent monitor tiles, with familiar CC:Tweaked-style drawing methods and deterministic interaction events.

## Requirements

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

### Requirement: Bounded sparse animation presentation
The presenter SHALL retain bounded dirty-cell metadata and MAY reuse unchanged native cells without preparing or retiring every grid cell. Damage acknowledgement SHALL NOT consume later writes, coalesced pending changes or a newer full-invalidation epoch. Full clear, scroll, palette, geometry and untracked legacy state SHALL retain a conservative full-frame path. Existing snapshot coherence, synchronous model visibility, admission, ownership, retirement and aggregate caps remain binding.

#### Scenario: Complete bounded chart frames at two-tick cadence
- **WHEN** the maintained smooth-sine-chart example updates all four selected screens every two actual simulation ticks within the documented scale-2 6×6 or mixed-layout test envelope and configured default guest budgets
- **THEN** headless acceptance measures at least 360 complete publication intervals per layout and engine mode, each at most two simulation ticks apart after warmup
- **AND** actual native fronts agree with one shared phase, including after ordinary cold reload and periodic rediscovery
- **AND** paused fixture snapshot-writing boundaries are separated from uninterrupted cadence windows; neither cadence nor scheduler profiles claim graphical-client FPS.

#### Scenario: A large old frame has accumulated later writes
- **WHEN** more model writes occur after a large snapshot is sealed and before it publishes
- **THEN** its prepaid acknowledgement consumes only matching cells from the same invalidation epoch and retains later changes for the next frame
- **AND** the presenter does not increase native-object, preparation-cell, commit or maintenance caps to conceal the cost.

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

### Requirement: Quiescent presentation work elision
A settled display with unchanged model, geometry, availability and ownership SHALL retain its complete native image without recurring snapshot capture, cell preparation, full-frame traversal or redundant native visibility writes. Idle presentation work SHALL NOT scale with the number of unchanged displays. Necessary live physical observation and retained-selection authority checks remain required by device lifecycle.

#### Scenario: Powered screens after their writer stops
- **WHEN** four powered 6×6 displays have complete fronts, no pending preparation or retirement, no physical changes and a stopped saved program
- **THEN** their images remain visible, including configured native cursor blink
- **AND** subsequent unchanged ticks perform no snapshot captures, cell preparations, full-frame traversals, native-object creation/retirement or redundant visibility writes for those displays.

#### Scenario: One changing screen among unchanged peers
- **WHEN** one of four independent logical displays receives drawing updates while all 144 physical tiles remain present and powered
- **THEN** only the changing display and genuinely unfinished work receive presentation service
- **AND** the other three displays do not acquire new presentation work merely because a program is running or another display changed.

#### Scenario: Read-only access to a settled display
- **WHEN** an authorized program reads monitor properties, limits or synchronization status without changing state
- **THEN** the returned values and live authorization remain correct
- **AND** the read does not itself create a frame, drive rendering or renew maintenance credits.

### Requirement: Coalesced demand without changing synchronous calls
Successful terminal calls SHALL retain synchronous model visibility and existing return/error semantics. Repeated calls SHALL coalesce eligible presentation demand instead of retaining work proportional to call history. A started immutable frame SHALL finish without restart for newer writes. Successful no-op mutations SHALL preserve synchronized-round participation without requiring unnecessary native sprite reconstruction.

#### Scenario: Burst followed by quiescence
- **WHEN** several successful writes occur before the post-dispatch presentation boundary and no later changes occur
- **THEN** reads during the callback observe the latest shared model immediately
- **AND** bounded pending work presents the latest complete accepted model within the existing supported latency envelope, then drains to quiescence.

#### Scenario: Later writes while an older frame is preparing
- **WHEN** new model updates arrive during preparation or credit deferral of an older immutable frame
- **THEN** the older admitted frame is not repeatedly restarted
- **AND** acknowledging it does not discard later damage or a newer full-invalidation epoch, while unrelated eligible displays retain fair progress.

#### Scenario: No-op completes a selected round
- **WHEN** a selected group is waiting for one member and that member successfully repeats an unchanged mutating setter
- **THEN** the round can seal after dispatch and publish under the existing shared sequence rules
- **AND** unchanged native components can be reused; getters and rejected mutations do not satisfy participation.

#### Scenario: A callback fails after successful writes
- **WHEN** an authorized callback changes a display and subsequently faults or receives a rejected operation
- **THEN** earlier accepted model updates remain eligible for presentation
- **AND** the failed operation adds neither partial model mutation nor false participation.

### Requirement: Change-triggered grouping reconciliation
Monitor grouping SHALL reconcile only after relevant topology or grouping-policy invalidation, or to continue an admitted unfinished reconciliation. Stable ticks SHALL NOT rebuild the complete tile signature or repartition unchanged walls. Deterministic grouping, retained-anchor identity, absorbed-name detachment and resize semantics SHALL remain unchanged.

#### Scenario: Stable wall with or without active drawing
- **WHEN** compatible tile placement, orientation, force, surface and grouping policy remain unchanged across ticks
- **THEN** neither stopped programs nor continuous terminal drawing cause full tile-signature reconstruction or repartitioning.

#### Scenario: A real topology change
- **WHEN** placement, actual removal, movement, rotation or scope change alters a wall
- **THEN** bounded reconciliation produces the same valid rectangles and identity/resize outcomes as the established grouping contract
- **AND** unrelated surviving groups retain their models and complete fronts rather than being redrawn solely because reconciliation ran.

#### Scenario: Invalidation arrives during deferred reconciliation
- **WHEN** another relevant change occurs while reconciliation is incomplete or its work admission is refused
- **THEN** the change remains pending until a partition for the current physical state commits
- **AND** completing older work cannot acknowledge the newer invalidation or expose obsolete geometry as current.

### Requirement: Complete presentation wakeup coverage
Every accepted state change that affects presentation SHALL make the affected display or selected group eligible for necessary work without requiring an extra guest drawing call. Unfinished preparation, publication, visibility restoration, notification and object retirement SHALL continue under existing budgets. Waiting groups SHALL NOT time out into partial publication.

#### Scenario: Settings paste without a running producer
- **WHEN** native settings paste changes a settled monitor's palette, scale or cursor blink while its saved program is stopped
- **THEN** the affected display receives the required invalidation and presentation work without a dummy write
- **AND** existing settings inheritance, dimension-change clearing and resize-notification semantics remain binding, without bypassing selected-group participation rules.

#### Scenario: Power restoration with no new drawing
- **WHEN** a member's power outage has hidden its logical display and power subsequently returns without a guest call
- **THEN** the retained model can become visible again under the existing full-group power and admission rules
- **AND** restoration neither fabricates a resize nor publishes only part of a selected replacement group.

#### Scenario: Waiting, blocked and retiring work
- **WHEN** a selected round lacks participation, required power is unavailable, or objects remain to be retired
- **THEN** incomplete rounds do not trigger repeated snapshot capture and do not partially publish
- **AND** participation, restoration or a renewed actual-tick work allowance resumes the appropriate deferred work, while retirement completes without another drawing call.

### Requirement: Durable demand-driven progress
Save/load and upgrade SHALL preserve accepted model state, valid complete fronts, selections, participation, pending work, paid progress and same-tick credits. New scheduling metadata SHALL be initialized in permitted synchronized stages without guest replay or mutation on load. Unknown retained formats SHALL remain recoverable and fail closed rather than being treated as empty work.

#### Scenario: Ordinary cold load at each work boundary
- **WHEN** a separate process loads an idle display, a partially participating selection, a pending snapshot, a partially prepared frame, a ready-but-deferred publication or unfinished retirement
- **THEN** the matching work state resumes deterministically with its exact accepted state and paid progress
- **AND** idle fronts are not unnecessarily rebuilt, staged objects remain hidden, completed guest effects do not replay and credits do not renew in the same tick.

#### Scenario: Upgrade an unchanged 0.1.16 wall
- **WHEN** a save created by immutable 0.1.16 lacks the new demand bookkeeping but contains valid displays and unfinished presentation work
- **THEN** synchronized initialization enrolls the existing required work exactly once, without moving tiles or requiring guest writes
- **AND** unchanged geometry retains its logical identities, cells and valid complete fronts; subsequent settled ticks meet the quiescent-work contract.

### Requirement: Structural performance acceptance and matched timing reports
Acceptance SHALL prove absence of unnecessary recurring work and publish matched whole-scheduler timings for no-monitor, idle, partly updating and continuously updating workloads. Numerical timings SHALL be reported without a fixed millisecond or percentage pass/fail threshold. Functional cadence, authority, accounting and lifecycle assertions SHALL remain mandatory; headless timings SHALL NOT be represented as client FPS or full-modpack acceptance.

#### Scenario: Structural regression gates
- **WHEN** settled, one-screen-updating and continuously updating fixtures run through actual production scheduler ticks
- **THEN** counters assert the absence of idle captures, frame scans and topology reconstruction, coalesced bounded demand, and no duplicate full monitor maintenance
- **AND** required live observation, selected-path checks and fresh operation-boundary proofs are counted separately rather than removed or disguised as presentation savings.

#### Scenario: Matched baseline and candidate workloads
- **WHEN** performance evidence compares immutable 0.1.16 with the candidate on the same reference host
- **THEN** serial runs use matching engine/content modes, physical tile counts, guest source, topology, scale, budgets, warmup and measured windows
- **AND** the report contains a zero-monitor control, 144 settled tiles with a stopped program, one updating screen among four 6×6 screens, and all four screens continuously updating, with sparse-row and full-row submission distinguished.

#### Scenario: Complete and honest timing evidence
- **WHEN** a timing report is accepted
- **THEN** exact sample counts, completion markers, live device/power/producer assertions, cold-phase results, clean exits and tested payload hashes are verified
- **AND** mean, median, p95 and maximum whole-scheduler timings are reported separately from instrumented phase attribution, including regressions and known host contention rather than an invented lower bound or speedup.
