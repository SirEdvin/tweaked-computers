# computer-runtime delta

## MODIFIED Requirements

### Requirement: Simulation timers and bounded queues
Timers SHALL use simulation ticks, persist deadlines and address named handlers. One-shot timers SHALL fire at most once; recurring timers SHALL not replay unbounded missed intervals. Event backlog SHALL remain bounded with visible fault-on-overflow behavior. Native circuit snapshot size SHALL not consume generic guest-payload byte/node capacity; circuit notifications SHALL still consume queue entries and bounded envelope accounting.

#### Scenario: Paused game and closed save
- **WHEN** simulation ticks do not advance
- **THEN** timer deadlines do not advance through wall-clock time.

#### Scenario: Overdue timer after a power interruption
- **WHEN** an upgrade resumes a legacy electrically paused run whose recurring deadlines have passed
- **THEN** at most one overdue event per timer is admitted with its missed-interval count
- **AND** the next deadline remains aligned to the original interval.

#### Scenario: Large observation fits an otherwise available queue
- **WHEN** a trusted circuit notification has more native signal data than generic Data/peripheral payload ceilings allow, but a queue entry and its envelope fit
- **THEN** its complete observation is retained and delivered without a size-induced fault or truncated arrays.

#### Scenario: Slow consumer still reaches backlog protection
- **WHEN** pending notifications exhaust the existing queue entry or envelope allowance
- **THEN** the existing visible overflow fault and output cleanup occur
- **AND** no unlimited backlog, drop-newest policy or suspension mechanism is introduced.

#### Scenario: Cold delivery preserves the accepted observation
- **WHEN** a save contains accepted subscriptions and large undispatched circuit events
- **THEN** cold load retains their observation data, ordering and run identity without startup or output replay
- **AND** subsequent dispatch does not reintroduce a generic payload ceiling or use retained observations to answer fresh reads.

## ADDED Requirements

### Requirement: Demand-driven computer service
A computer SHALL receive recurring execution service only while it has admitted program events or Console submissions. Waiting with no queued work SHALL not cause a timer, dispatch or subscription-discovery visit every tick. Adding unrelated idle computers or devices MUST NOT increase those recurring visits.

#### Scenario: Idle population scaling
- **WHEN** an unchanged active workload is surrounded by additional stopped or waiting computers with no deadlines, subscriptions, owned outputs or open UI
- **THEN** the idle computers receive zero timer, dispatch and signal-work discovery visits; only explicitly due low-frequency physical bookkeeping may visit them.

#### Scenario: Event wakes an otherwise sleeping computer
- **WHEN** an eligible timer, signal, modem, monitor, dashboard or explicit Console submission is admitted
- **THEN** the destination becomes runnable without discovering it through a full registry scan and the admitted item executes at most once.

#### Scenario: Fair competition and reentrant producers
- **WHEN** programs and Console submissions compete while a handler produces more events
- **THEN** each computer receives at most one executable item per actual tick, program/Console arbitration and fair neighbor service remain bounded, and no callback executes inside its producer.

#### Scenario: Queue drained or run retired
- **WHEN** dispatch empties a queue or stop, fault, replacement, removal or authorization retirement cancels its work
- **THEN** the affected execution membership is removed; later valid work wakes the correct generation without reviving canceled items.

### Requirement: Deadline-driven simulation timers
Future timers SHALL cause no per-computer per-tick search. Due timers SHALL preserve per-computer deadline/creation ordering, cancellation, aligned recurring deadlines, missed-interval coalescing and existing budgets. Dispatch may be later than admission; simulation time remains authoritative.

#### Scenario: Far future deadline
- **WHEN** a running computer has only a far-future timer
- **THEN** ticks before its due deadline do not visit that computer to check its timers; the deadline is not delayed by its previous idleness.

#### Scenario: Cancellation and replacement
- **WHEN** a timer is canceled, its run ends, or its recurring deadline advances
- **THEN** obsolete deadlines cannot fire or leave unbounded retained cancellation history.

#### Scenario: Admission pressure
- **WHEN** a timer is overdue or already has an undispatched recurring event
- **THEN** due work remains represented under budget deferral, recurring events coalesce with the original scheduled tick and missed count, and unrelated due/runnable computers retain fair opportunities.

### Requirement: Electricity-independent computer lifecycle
Computers SHALL consume no electricity and SHALL execute without an electrical network. Stop and fault SHALL cancel the run's events, timers and subscriptions and clear only its still-owned transient resources while retaining source and explicit state. Electrical supply changes SHALL not pause, restart, cancel or resynchronize execution.

#### Scenario: No electrical connection
- **WHEN** a valid computer is placed without electrical coverage and explicitly started
- **THEN** its startup, timers, signals and Console operate under ordinary authority and execution budgets.

#### Scenario: Factory power cycle
- **WHEN** electricity near a running computer disappears and returns
- **THEN** run identity, queues, deadlines and state remain unchanged; no startup replay, transient discard or artificial signal resync occurs.

#### Scenario: Last writer still owns cleanup
- **WHEN** a computer stops or faults after another computer has overwritten its output
- **THEN** only resources still owned by the retiring run are cleared; the newer writer remains authoritative.

### Requirement: Durable work membership
Save/load SHALL preserve runnable order, deadlines, active observations, pending maintenance and spent credits without startup replay or authoritative mutation in load callbacks. One-time versioned migration SHALL build missing memberships before ordinary ticking. Stale identity/generation entries MUST NOT authorize work.

#### Scenario: Cold load with mixed work
- **WHEN** a save contains idle devices, queued commands/events, canceled timers, active subscriptions and pending presentation
- **THEN** each valid item continues once in deterministic order, idle devices remain unscheduled, canceled work stays canceled and same-tick credits do not renew.

#### Scenario: Late joining peer
- **WHEN** a peer joins while queued work and shared deadlines exist
- **THEN** all peers derive identical work order and effects from synchronized retained state, not a process-local rebuilt queue.

#### Scenario: Unsupported scheduling representation
- **WHEN** retained scheduling data cannot be safely validated
- **THEN** affected execution stays inert with an actionable diagnostic and preserved source/data, without resetting ledgers or silently rebuilding from untrusted metadata.

### Requirement: Inert legacy power-restoration registration
The existing `power_restored` registration name SHALL remain accepted for source/save compatibility, but custom computers SHALL generate no new power-restoration events. Such registrations SHALL create no observation or scheduling work. Already admitted events SHALL retain ordinary queue ordering and cancellation semantics; migration MUST NOT fabricate a restoration event.

#### Scenario: Existing program registers power restoration
- **WHEN** existing source or a retained run registers `power_restored`
- **THEN** registration and explicit cancellation retain their documented return behavior, but electrical changes cause no polling or notification.

#### Scenario: Previously admitted restoration event
- **WHEN** an old save already contains an admitted `power_restored` callback
- **THEN** it remains an accepted historical queue item subject to normal dispatch/cancellation, and the upgrade creates no duplicate event.

## REMOVED Requirements

### Requirement: Stop and power semantics
**Reason**: Custom computers no longer require electricity; power-pause/resume is intentionally retired.
**Migration**: Preserve source/state and run identity; migrate a legacy paused run once as specified by device-lifecycle. Explicit stop/fault cleanup remains required by Electricity-independent computer lifecycle.
