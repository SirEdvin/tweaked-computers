# monitor-display delta

## MODIFIED Requirements

### Requirement: Character-cell touch events
A valid world interaction with a valid display SHALL map to a 1-based character cell and emit `monitor_touch` to registered authorized computers. Border/outside clicks, GUI-hover input and unauthorized interaction MUST NOT create touch events.

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
Authorized computers SHALL share one committed display state. Save/load SHALL preserve contents, colors, palette, cursor and scale. Writer stop or disconnect SHALL not clear the display; electrical supply SHALL not affect its image or model.

#### Scenario: Writer stops after drawing
- **WHEN** the last drawing computer stops
- **THEN** the monitor continues displaying its last committed image.

### Requirement: Visible native deconstruction feedback
Each monitor tile marked for deconstruction SHALL visibly show the native red deconstruction marker above its displayed content and decoration. Marking MUST NOT be represented only by a custom fault symbol, a hidden helper state or a console message. Feedback SHALL work on idle and actively redrawing displays, with or without electrical coverage.

#### Scenario: Mark a running display
- **WHEN** the player marks a monitor displaying text and changing colors
- **THEN** the native red X remains legible while the tile awaits removal, regardless of continuing redraws or cursor blinking.

#### Scenario: Mark part of a merged display
- **WHEN** only some tiles in a merged monitor are marked
- **THEN** each marked tile has unambiguous native removal feedback and unmarked tiles do not falsely appear marked.

### Requirement: Automatic snapshot presentation
Monitor drawing SHALL buffer presentation automatically without requiring a flush or frame-control call. Successful operations SHALL update the shared model synchronously. Automatic snapshots SHALL be taken after synchronized callback dispatch, never midway through a callback. The previous complete visible image SHALL remain until its replacement is ready, except for geometry or identity invalidation.

#### Scenario: Existing program draws without a new API
- **WHEN** an existing callback clears and redraws a monitor using existing terminal methods
- **THEN** subsequent calls observe the updated model immediately
- **AND** the world transitions from the previous image to a prepared snapshot without a renderer-generated row sweep.

#### Scenario: Later call fails
- **WHEN** a callback makes successful monitor changes and then encounters a rejected call or faults
- **THEN** its earlier successful model changes remain eligible for automatic presentation
- **AND** neither the rejected operation nor callback failure introduces a model rollback transaction.

### Requirement: Bounded buffering and admission
Snapshot retention, preparation, retirement, native objects, group size and whole-group commit work SHALL have published enforceable limits. Unsupported group registration SHALL fail before replacing the prior selection. Exhausted preparation or commit credits SHALL defer the entire remaining operation without partially publishing a frame. Guest and aggregate safety limits SHALL NOT be raised to conceal an infeasible commit.

#### Scenario: Supported large group
- **WHEN** four 6×6 scale-1 logical screens totaling 10,584 cells are selected within the published envelope
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
- **WHEN** changes stop and selected groups have completed participation with stable geometry and authority
- **THEN** final visible contents match the latest accepted model within the supported latency envelope.

### Requirement: Lifecycle-safe buffered state
Save/load SHALL preserve complete visible state, accepted model state, pending snapshots, group selections, paid progress and spent same-tick credits without executing guest code on load. Electrical changes SHALL not hide output, clear its model or invalidate buffered work. Geometry/identity invalidation SHALL prevent stale publication and unsafe touch mapping; removal SHALL retire all owned staged and visible objects.

#### Scenario: Cold load during preparation
- **WHEN** the game is saved with an old visible frame, a partially prepared hidden frame and newer pending writes
- **THEN** a separate process resumes those states without exposing staged objects, replaying the producer or renewing credits.

#### Scenario: Resize during preparation
- **WHEN** scale, topology or rotation invalidates a prepared frame
- **THEN** that frame cannot publish with stale geometry
- **AND** touches are ignored while visible and authoritative grid geometry disagree, rather than reported against the wrong image.

#### Scenario: Power outage
- **WHEN** electrical supply around one group member disappears and returns
- **THEN** its retained image and model remain available and buffered work follows normal whole-group admission
- **AND** no power restoration job or fabricated resize is generated.

### Requirement: Safe monitor inspector updates
The inspector SHALL follow the originally selected physical tile while revalidating its logical-group mapping. Split or merge changes SHALL refresh the displayed name and dimensions together after commit. Removal or replacement of the selected tile SHALL invalidate the session. Monitors outside electrical coverage SHALL retain inspectable committed geometry without modifying their saved display model.

#### Scenario: Selected tile survives a split
- **WHEN** another tile is removed and the selected tile belongs to a new resulting rectangle
- **THEN** the inspector resolves that tile's current logical display and presents its identity and sizes coherently, including an identity-change indication when needed.

#### Scenario: Selected tile is replaced
- **WHEN** the selected tile is removed and another occupies its coordinates
- **THEN** the old inspector becomes unavailable rather than attaching itself to the replacement.

#### Scenario: Inspect an unpowered monitor
- **WHEN** an authorized player opens a monitor outside electrical coverage whose committed group data is valid
- **THEN** its name and committed tile/terminal dimensions remain readable, its complete world image remains visible and its model is unchanged, without an unpowered label.

### Requirement: Quiescent presentation work elision
A settled display with unchanged model, geometry, availability and ownership SHALL retain its complete native image without recurring snapshot capture, cell preparation, full-frame traversal or redundant native visibility writes. Idle presentation work SHALL NOT scale with the number of unchanged displays. Targeted and bounded due physical observation and retained-selection authority checks remain required by device lifecycle; they do not justify every-tick scans of settled displays.

#### Scenario: Powered screens after their writer stops
- **WHEN** four 6×6 displays have complete fronts, no pending preparation or retirement, no physical changes and a stopped saved program
- **THEN** their images remain visible, including configured native cursor blink
- **AND** subsequent unchanged ticks perform no snapshot captures, cell preparations, full-frame traversals, native-object creation/retirement or redundant visibility writes for those displays.

#### Scenario: One changing screen among unchanged peers
- **WHEN** one of four independent logical displays receives drawing updates while all 144 physical tiles remain valid
- **THEN** only the changing display and genuinely unfinished work receive presentation service
- **AND** the other three displays do not acquire new presentation work merely because a program is running or another display changed.

#### Scenario: Read-only access to a settled display
- **WHEN** an authorized program reads monitor properties, limits or synchronization status without changing state
- **THEN** the returned values and live authorization remain correct
- **AND** the read does not itself create a frame, drive rendering or renew maintenance credits.

### Requirement: Complete presentation wakeup coverage
Every accepted state change that affects presentation SHALL make the affected display or selected group eligible for necessary work without requiring an extra guest drawing call. Unfinished preparation, publication, visibility restoration, notification and object retirement SHALL continue under existing budgets. Waiting groups SHALL NOT time out into partial publication.

#### Scenario: Settings paste without a running producer
- **WHEN** native settings paste changes a settled monitor's palette, scale or cursor blink while its saved program is stopped
- **THEN** the affected display receives the required invalidation and presentation work without a dummy write
- **AND** existing settings inheritance, dimension-change clearing and resize-notification semantics remain binding, without bypassing selected-group participation rules.

#### Scenario: Power restoration with no new drawing
- **WHEN** electrical supply around a member disappears and returns without a guest call
- **THEN** the complete retained image stays visible and electrical changes create no presentation work
- **AND** any real pending replacement still obeys whole-group admission without a fabricated resize.

#### Scenario: Waiting, blocked and retiring work
- **WHEN** a selected round lacks participation, required identity or geometry is unavailable, or objects remain to be retired
- **THEN** incomplete rounds do not trigger repeated snapshot capture and do not partially publish
- **AND** participation, valid physical repair or a renewed actual-tick work allowance resumes the appropriate deferred work, while retirement completes without another drawing call.

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
- **THEN** exact sample counts, completion markers, live device/producer assertions and unchanged native-endpoint power assertions where relevant, cold-phase results, clean exits and tested payload hashes are verified
- **AND** mean, median, p95 and maximum whole-scheduler timings are reported separately from instrumented phase attribution, including regressions and known host contention rather than an invented lower bound or speedup.

## ADDED Requirements

### Requirement: Demand-owned monitor topology and notifications
Monitor grouping SHALL run only for pending topology work. Resize/touch delivery SHALL visit pending notifications and registered recipients, not all display or computer identities to find them. Completing or canceling work SHALL remove its membership while retaining complete-frame publication, selected-path validation and existing bounded delivery behavior.

#### Scenario: No pending monitor event
- **WHEN** settled monitors have no topology change, resize, touch, rendering or retirement work
- **THEN** the grouping/notification/presentation phases perform no per-monitor or per-computer discovery walk.

#### Scenario: Input creates work without a producer
- **WHEN** a real touch, settings paste or physical transition affects a stopped-producer display
- **THEN** only the affected pending topology, notification and presentation work becomes eligible; callbacks remain scheduled rather than inline.

#### Scenario: Late physical invalidation
- **WHEN** a silent physical change is discovered by bounded observation or a fresh operation proof
- **THEN** stale touch mapping or staged geometry cannot publish, necessary cleanup remains pending through deferral/reload and unchanged unrelated monitors stay asleep.
