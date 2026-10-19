# logic-handler Specification

## Purpose

Bridge bounded computer programs to ordinary Factorio circuit signals through physically distinct input, computer-network and output sections, with deterministic change notifications and fail-safe outputs.

## Requirements

### Requirement: Three isolated physical roles
A logic handler SHALL occupy a rotatable 3×1 footprint with input, middle computer-network and output sections. Each role SHALL provide clearly identified red/green connection points. Factory signal roles MUST NOT connect internally to the discovery role or relay discovery paths.

#### Scenario: Rotate the handler
- **WHEN** the player rotates a placed handler
- **THEN** all three roles rotate consistently and remain visibly distinguishable without swapping their logical meanings or leaking signals between them.

### Requirement: Quality-aware input inspection
The API SHALL require an explicit red or green input selector and SHALL NOT combine colors or supply a default. Missing, both and invalid selectors SHALL fail before subscription registration. Signal identities SHALL include type, name and quality, including installed recipe prototypes independently of same-named items. Missing signals SHALL read as zero, and collections SHALL be canonical, bounded defensive snapshots.

#### Scenario: Same item at different qualities
- **WHEN** normal and higher-quality item signals exist together
- **THEN** they remain distinct in reads, filters, output and change notifications.

#### Scenario: Red and green isolation
- **WHEN** both physical input colors are connected and a caller selects red or green
- **THEN** only that color's native signed-32-bit values are returned; selecting both or omitting the selector fails without registration or mutation.

### Requirement: Shared combinator-style output
The handler SHALL hold one output signal set broadcast identically on red and green output wires. API writes SHALL replace or update that set as documented, validating all identities, counts and capacity before mutation. It MUST NOT offer independent output banks by color.

#### Scenario: Output is visible on either wire color
- **WHEN** an authorized computer successfully replaces the output set
- **THEN** red and green output networks receive the same contribution through Factorio's native circuit update behavior.

#### Scenario: Rejected output remains unchanged
- **WHEN** a write contains duplicate identities, an invalid prototype/quality, an out-of-range count or exceeds capacity
- **THEN** the previous output and writer ownership remain unchanged.

### Requirement: Tick-sampled change subscriptions
Programs SHALL subscribe named handlers to explicitly selected red or green input snapshots, optionally filtered by signal identity. Within the supported envelope, powered handlers SHALL be sampled once per simulation tick and only changed samples or explicitly requested initial/resync samples SHALL produce events.

#### Scenario: Unchanged input
- **WHEN** consecutive selected input snapshots and connectivity are identical
- **THEN** no redundant change event is emitted.

#### Scenario: Signal disappears
- **WHEN** a previously nonzero subscribed signal becomes absent
- **THEN** the event includes its previous value and a current value of zero, not merely a list omitting it.

#### Scenario: Input connection changes without values
- **WHEN** an empty input network is disconnected
- **THEN** the subscription can distinguish the connectivity change from a still-connected zero-valued input.

### Requirement: Defined observation and delivery timing
The API SHALL distinguish sample tick from callback-dispatch tick and document native previous-circuit-step observations. It MUST NOT promise same-tick combinational feedback or detection of changes occurring entirely between sampled engine states.

#### Scenario: Controller writes a response
- **WHEN** a callback reacts to a sampled input and writes output
- **THEN** the output becomes observable according to native circuit propagation, not through a fabricated immediate recursive signal event.

### Requirement: Last-writer authority and fail-safe cleanup
The output set SHALL record its last successful writer's computer identity, run generation and access channel. Stop, fault, power loss, invalidation or loss of that writer's access SHALL clear its still-owned output. Cleanup MUST run independently of user callbacks.

#### Scenario: A newer writer remains authoritative
- **WHEN** computer A writes, computer B overwrites, and A then stops
- **THEN** B's output remains intact.

#### Scenario: Last writer loses its cable
- **WHEN** the selected same-color path of the current writer becomes invalid
- **THEN** the handler clears the owned output within the published fail-safe reconciliation envelope, even if the writer ignores its detach event.

### Requirement: Durable ownership without replay
Save/load SHALL retain valid output values, ownership and subscriptions without replaying writes or granting a new run generation. Blueprint/clone placement SHALL begin with zero output and no writer. Mining/removal SHALL remove subscriptions and invalidate stale handles safely.

#### Scenario: Reload after one completed output write
- **WHEN** the save is loaded in a new process
- **THEN** the retained valid output remains the same and no duplicate write event or `start` invocation is required to preserve it.

#### Scenario: Reload with a legacy combined subscription
- **WHEN** a retained signal subscription has both, missing or invalid input selection
- **THEN** the run faults before queued callbacks dispatch, clears its still-owned outputs and discards pending callbacks without silently choosing a wire; the user must update source and restart.

### Requirement: Input and network power policy
An unpowered handler SHALL not execute peripheral services or emit owned output. Subscription resumption SHALL rebaseline current inputs and mark resynchronization, without replaying an unbounded backlog of unobserved changes.

#### Scenario: Restore handler power
- **WHEN** an authorized subscription survives a handler power interruption
- **THEN** it receives a current resync sample after restoration and outputs remain zero until a new successful write.
