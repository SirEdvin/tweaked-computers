## MODIFIED Requirements

### Requirement: Scale and resize semantics
Text scale SHALL accept positive finite values whose geometry is representable and fits configured resources, without the former range or half-step restriction. A change in physical group geometry or text scale SHALL recompute terminal dimensions. When character dimensions change, the display SHALL clear and notify accessible registered computers with `monitor_resize`.

#### Scenario: Larger array changes dimensions
- **WHEN** adding tiles increases the display's character dimensions
- **THEN** the new buffer is blank using the retained current colors, cursor position/blink and palette remain defined by the API contract, and resize is emitted after the new dimensions are readable.

#### Scenario: Invalid scale
- **WHEN** a scale is nonpositive, nonfinite or produces unrepresentable geometry
- **THEN** the monitor remains unchanged and the program receives an E_RANGE error.

### Requirement: Bounded rendering without hidden loss
Tile dimensions SHALL retain a configurable maximum of six per axis. Cells, text payloads and rendering SHALL use queryable aggregate resource accounting without independent fixed capacities. Accepted model updates SHALL be presented with fair progress under stable adequate configured resources. Rendering backlog MUST NOT silently lose the most recent committed revision.

#### Scenario: Rapid updates followed by idle
- **WHEN** several valid updates arrive before rendering catches up
- **THEN** the final displayed cells match the latest complete committed model, not a falsely current mixed-revision sweep.

### Requirement: Bounded sparse animation presentation
The presenter SHALL retain bounded dirty-cell metadata and MAY reuse unchanged native cells without preparing or retiring every grid cell. Damage acknowledgement SHALL NOT consume later writes, coalesced pending changes or a newer full-invalidation epoch. Full clear, scroll, palette, geometry and untracked legacy state SHALL retain a conservative full-frame path. Existing snapshot coherence, synchronous model visibility, admission, ownership, retirement and configurable resource-policy remain binding.

#### Scenario: Complete bounded chart frames at two-tick cadence
- **WHEN** the maintained smooth-sine-chart example updates all four selected screens every two actual simulation ticks within the documented scale-2 6×6 or mixed-layout test envelope and configured default guest budgets
- **THEN** headless acceptance measures at least 360 complete publication intervals per layout and engine mode, each at most two simulation ticks apart after warmup
- **AND** actual native fronts agree with one shared phase, including after ordinary cold reload and periodic rediscovery
- **AND** paused fixture snapshot-writing boundaries are separated from uninterrupted cadence windows; neither cadence nor scheduler profiles claim graphical-client FPS.

#### Scenario: A large old frame has accumulated later writes
- **WHEN** more model writes occur after a large snapshot is sealed and before it publishes
- **THEN** its prepaid acknowledgement consumes only matching cells from the same invalidation epoch and retains later changes for the next frame
- **AND** the presenter accounts actual retained resources and work rather than reinstating arbitrary frame/cell-count caps.

### Requirement: Complete rectangular displays up to six tiles per axis
Compatible monitor tiles SHALL support every complete rectangular logical display with local width and height from one through six tiles. Narrow, nonsquare and square displays SHALL use the same grouping rules at every supported text scale and cardinal orientation. Irregular or oversized walls SHALL still partition deterministically into valid rectangles.

#### Scenario: All supported rectangular dimensions
- **WHEN** a compatible complete W×H wall has each local dimension between one and six, including 1×1, 1×6, 3×6, 6×3, 6×1 and 6×6
- **THEN** it can form one logical display without a world-wide tile-count ceiling when resource admission permits, rather than being split at the old four-tile boundary
- **AND** formerly supported scales remain supported alongside other resource-admissible positive scales.

#### Scenario: Oversized or irregular wall
- **WHEN** a wall exceeds six tiles on an axis or contains holes or an L-shaped arrangement
- **THEN** it partitions into nonoverlapping complete rectangles with neither axis above six, preserving the established identity and ordering rules.

### Requirement: Geometry-driven buffering
Buffering SHALL derive cell layout, allocation, clipping, preparation progress and admission from each display's actual width, height, scale and orientation. Smaller screens SHALL NOT require a padded maximum-size buffer. A supported nonsquare shape SHALL NOT be rejected because buffering assumes square screens or equal dimensions across a synchronization group.

#### Scenario: Mixed screen geometries
- **WHEN** a selected group contains 1×1, 3×6 and 6×6 displays whose actual combined cells fit configured aggregate resource capacity
- **THEN** each prepares its own complete image with correct row strides, cursor, palette and orientation
- **AND** the group publishes together without stretching, square padding or equal-resolution requirements.

#### Scenario: Maximum supported resolution
- **WHEN** a 6×6 display uses scale 0.5
- **THEN** its 126×84 grid of 10,584 cells is supported by automatic singleton buffering, staging, retirement and whole-frame publication.

### Requirement: Automatic snapshot presentation
Monitor drawing SHALL buffer presentation automatically without requiring a flush or frame-control call. Successful operations SHALL update the shared model synchronously. Automatic snapshots SHALL be taken after invocation completion or termination, not at budget-suspension boundaries. Displays touched by unfinished invocations SHALL retain their previous complete fronts until those invocations finish or are explicitly canceled. The previous complete visible image SHALL remain until its replacement is ready, except for power, geometry or identity invalidation.

#### Scenario: Existing program draws without a new API
- **WHEN** an existing callback clears and redraws a monitor using existing terminal methods
- **THEN** subsequent calls observe the updated model immediately
- **AND** the world transitions from the previous image to a prepared snapshot without a renderer-generated row sweep.

#### Scenario: Later call fails
- **WHEN** a callback makes successful monitor changes and then encounters a rejected call or faults
- **THEN** its earlier successful model changes remain eligible for automatic presentation
- **AND** neither the rejected operation nor callback failure introduces a model rollback transaction.

### Requirement: Synchronized group update rounds
An explicitly selected monitor group SHALL wait for a successful mutating terminal operation on every member after registration or the preceding snapshot seal. Once all members participate, their current models SHALL be captured at one post-dispatch boundary only when no unfinished invocation has modified those members. All prepared members SHALL publish in the same simulation tick with one group sequence. Waiting SHALL NOT time out into partial publication.

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
Snapshot retention, preparation, retirement, native objects and indivisible commit work SHALL obey configurable resource policy; group references, member counts and group counts SHALL have no independent ceilings. Unsupported group registration SHALL fail before replacing the prior selection. Exhausted preparation or commit credits SHALL defer the entire remaining operation without partially publishing a frame. Guest and aggregate safety limits SHALL NOT be raised to conceal an infeasible commit.

#### Scenario: Supported large group
- **WHEN** four powered 6×6 scale-1 logical screens totaling 10,584 cells are selected within the published envelope
- **THEN** the group is supported without raising callback or shared host/maintenance ceilings
- **AND** its entire ready publication fits effective resource policy.

#### Scenario: Commit credits are insufficient
- **WHEN** the next ready group's whole commit cannot be admitted in the current tick
- **THEN** all its old frames stay visible, prepared replacements stay hidden, and publication is retried fairly later.

#### Scenario: Registered group grows beyond capacity
- **WHEN** a physical topology change or lowered resource setting would make the selected group exceed configured memory or indivisible-commit capacity
- **THEN** prior accepted model data is retained while the transition is pending; explicit scale changes that cannot fit memory are refused before clearing or replacing the model
- **AND** group publication is blocked with an observable E_CAPACITY diagnostic until resources are released, settings are raised or it is reconfigured, never silently split.

### Requirement: Bounded progress without stale-frame starvation
The presenter SHALL retain bounded pending updates, coalesce superseded pending snapshots, and finish an admitted snapshot without repeatedly restarting for newer writes. Unrelated eligible monitors/groups SHALL receive deterministic fair service. Within the published stable-world envelope, quiescent accepted state SHALL reach presentation with fair resource-admitted progress.

#### Scenario: Continuous updates
- **WHEN** one producer keeps changing a screen faster than preparation completes
- **THEN** complete images still publish and an unrelated eligible screen is not starved
- **AND** pending retention does not grow with the update history.

#### Scenario: Producer becomes idle
- **WHEN** changes stop and selected groups have completed participation with stable power, geometry and authority
- **THEN** final visible contents match the latest accepted model once finite outstanding work is processed under stable adequate resources.

## ADDED Requirements

### Requirement: Explicit geometry exception and safe settings changes
Monitor width and height settings SHALL default to six tiles and SHALL NOT exceed six. A decrease SHALL preserve existing accepted displays and contents; it SHALL govern new grouping without silently clearing or repartitioning old models. Native geometry changes SHALL retain established split/resize behavior.

#### Scenario: Lower a dimension setting
- **WHEN** an existing 6×6 display exceeds a newly lowered dimension setting
- **THEN** its data and identity remain inspectable and valid until an explicit topology change, while new grouping follows the configured bound.

### Requirement: Resource refusal preserves complete visible frames
A resource-refused update or selection SHALL preserve previous accepted model and front state. An indivisible whole-group commit larger than the configured tick allowance SHALL report actionable blockage, not loop indefinitely, split publication or exceed the allowance.

#### Scenario: Large group cannot commit under current settings
- **WHEN** preparation fits storage but atomic visibility commit exceeds the full configured allowance
- **THEN** old fronts remain visible and status identifies the required setting/resource; raising it permits progress without replaying the producer.
