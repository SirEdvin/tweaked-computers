# Spec Delta

## ADDED Requirements

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
