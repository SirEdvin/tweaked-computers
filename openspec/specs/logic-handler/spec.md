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

### Requirement: Combinator-style read-only signal panel
The Logic Handler inspector SHALL present one Input signals area and an adjacent Output signals area at normal supported widths. Red and green input entries SHALL appear together in the input area using native-style wire-colored slot backgrounds, grouped by wire with textual identification. The UI SHALL NOT expose expressions, conditions, signal pickers, count editors or output toggles.

#### Scenario: Both input colors carry signals
- **WHEN** red and green input networks both contain signals
- **THEN** both sets are visible together without a wire-selector tab, with red-backed and green-backed slots in the shared input area
- **AND** labels or tooltips identify wire origin without relying only on color.

#### Scenario: Same identity on both wires
- **WHEN** the same signal identity has a value on red and a different value on green
- **THEN** each wire's contribution remains distinguishable in its own colored slot rather than being collapsed into an unlabeled sum
- **AND** the guest API still requires an explicit single input color.

#### Scenario: Small supported window
- **WHEN** resolution or GUI scale requires a narrower layout
- **THEN** the signal regions reflow or scroll without hiding close/copy controls or losing the distinction between inputs and outputs.

### Requirement: Faithful signal identities and counts
Signal slots SHALL preserve type, prototype name, quality and signed count, including recipe signals distinct from same-named item signals. Exact counts and identity details SHALL be accessible even if slot overlays abbreviate large values. Disconnected inputs, connected networks with no nonzero signals, unavailable samples and capacity failures SHALL be distinguishable.

#### Scenario: Quality and namespace distinctions
- **WHEN** normal and higher-quality versions of an item, or an item and recipe with the same name, appear together
- **THEN** they remain separate entries with appropriate icons and unambiguous identity details.

#### Scenario: Negative or large values
- **WHEN** a sampled signal has a negative count or a value near a signed-32-bit boundary
- **THEN** the inspector preserves the exact value in its detail/tooltip presentation rather than rounding the authoritative count.

#### Scenario: Empty versus disconnected
- **WHEN** one input color is connected but has no nonzero signals and the other is disconnected
- **THEN** the shared input region distinguishes those states without fabricating zero-valued slots or reporting a failed query as empty.

### Requirement: Own output contribution rather than network totals
The Output signals area SHALL show the handler's own emitted bank, with an explicit label that it is shared across its red and green output wires. It SHALL NOT attribute signals from other emitters on an output network to this handler. Inspection SHALL NOT write a bank, claim ownership or change fail-safe cleanup behavior.

#### Scenario: Another emitter shares the output wire
- **WHEN** an unrelated device emits signals onto a network connected to the handler's output
- **THEN** the inspector shows only this handler's contribution, not the combined output-network totals.

#### Scenario: Writer or handler loses authority or power
- **WHEN** existing fail-safe reconciliation clears the handler's output
- **THEN** the next successful inspector update shows the cleared bank without replaying a write or restoring the former owner.

### Requirement: Bounded live signal observation
The open signal panel SHALL throttle observations, label per-wire ticks or pending/stale state, and publish only complete red/green pairs spanning at most 30 ticks. Separate-tick samples SHALL NOT be described as atomic. Incomplete pairs SHALL remain private and expire. Inspection SHALL NOT create guest subscriptions or promise pulse capture. Closing SHALL stop inspection without changing program subscriptions or output ownership.

#### Scenario: Signals change with the inspector open
- **WHEN** powered input values change and inspection work is admitted
- **THEN** the panel updates its displayed signals without reopening the window, altering subscriptions or changing the wire-selection contract.

#### Scenario: Query exceeds supported signal capacity
- **WHEN** a native input exceeds the existing supported signal limit or work admission fails
- **THEN** the panel reports the relevant limit/pending state rather than presenting a truncated signal set as complete or resetting logic output.
