## MODIFIED Requirements

### Requirement: Quality-aware input inspection
The API SHALL require an explicit red or green input selector and SHALL NOT combine colors or supply a default. Missing, both and invalid selectors SHALL fail before subscription registration. Signal identities SHALL include type, name and quality, including installed recipe prototypes independently of same-named items. Missing signals SHALL read as zero, and collections SHALL be canonical complete defensive snapshots without a mod-imposed signal-count or name-length ceiling.

#### Scenario: Same item at different qualities
- **WHEN** normal and higher-quality item signals exist together
- **THEN** they remain distinct in reads, filters, output and change notifications.

#### Scenario: Red and green isolation
- **WHEN** both physical input colors are connected and a caller selects red or green
- **THEN** only that color's native signed-32-bit values are returned; selecting both or omitting the selector fails without registration or mutation.

#### Scenario: Unrelated prototype catalogue grows
- **WHEN** installed mods add unrelated items, recipes, fluids, virtual signals or qualities without changing the selected input
- **THEN** read admission charges the native call and actual returned data, not the global prototype inventory; actual native domains, validation and configured resource-policy still apply.

### Requirement: Shared combinator-style output
The handler SHALL hold one output signal set broadcast identically on red and green output wires. API writes SHALL replace or update that set as documented, validating identities, native counts, engine capacity and configured resource admission before mutation, without a fixed mod output-slot count. It MUST NOT offer independent output banks by color.

#### Scenario: Output is visible on either wire color
- **WHEN** an authorized computer successfully replaces the output set
- **THEN** red and green output networks receive the same contribution through Factorio's native circuit update behavior.

#### Scenario: Rejected output remains unchanged
- **WHEN** a write contains duplicate identities, an invalid prototype/quality, an out-of-range count or exceeds capacity
- **THEN** the previous output and writer ownership remain unchanged.

### Requirement: Tick-sampled change subscriptions
Programs SHALL subscribe named handlers to explicitly selected red or green input snapshots, optionally filtered by signal identity without a fixed filter-count ceiling. Powered handlers SHALL be sampled once per simulation tick when admitted; overload SHALL defer sampling without retiring subscribers or clearing outputs and only changed samples or explicitly requested initial/resync samples SHALL produce events.

#### Scenario: Unchanged input
- **WHEN** consecutive selected input snapshots and connectivity are identical
- **THEN** no redundant change event is emitted.

#### Scenario: Signal disappears
- **WHEN** a previously nonzero subscribed signal becomes absent
- **THEN** the event includes its previous value and a current value of zero, not merely a list omitting it.

#### Scenario: Input connection changes without values
- **WHEN** an empty input network is disconnected
- **THEN** the subscription can distinguish the connectivity change from a still-connected zero-valued input.

### Requirement: Bounded live signal observation
Signal trays SHALL appear before query admission and publish complete per-wire samples independently with explicit ticks or pending/stale/error states. A refused input SHALL NOT block other inputs or own-output inspection. Separate-tick samples SHALL NOT be described as atomic. Inspection SHALL NOT create subscriptions or promise pulse capture; closing SHALL stop inspection without changing program subscriptions or output ownership.

#### Scenario: Signals change with the inspector open
- **WHEN** powered input values change and inspection work is admitted
- **THEN** the panel updates its displayed signals without reopening the window, altering subscriptions or changing the wire-selection contract.

#### Scenario: Query exceeds supported signal capacity
- **WHEN** a native input exceeds 64 signals or needs several work slices
- **THEN** the panel eventually publishes every signal under adequate configured resources, showing pending while processing rather than a cardinality error, truncated inventory or reset output.

#### Scenario: One input cannot be sampled
- **WHEN** an input repeatedly fails work admission while the other input and own output fit within unchanged host ceilings
- **THEN** all signal trays remain visible, the failed input is marked pending/stale/error, and the other regions continue updating independently.
- **AND** unknown samples are not shown as empty, while any retained older sample keeps its original tick and explicit refusal state.

## ADDED Requirements

### Requirement: Complete signal delivery under resource policy
Bulk reads, subscription baselines, filters, samples and changes SHALL support complete native inventories without hidden Data-entry or transport-count caps. Queue overload SHALL drop whole newest events with recorded loss, never truncate arrays. Sampling gaps and event loss SHALL remain distinguishable from an unchanged input.

#### Scenario: Large changing circuit
- **WHEN** 150 and more than 1,024 distinct native signal identities are read, filtered and subscribed to with adequate resource settings
- **THEN** all applicable values and changes are returned exactly, including disappearing signals as zero and quality/recipe distinctions.

#### Scenario: Delivery lost while sampling continues
- **WHEN** a change event is dropped because the queue is full
- **THEN** the drop counter advances and the next admitted change carries loss/resynchronization metadata plus a complete current snapshot
- **AND** a consumer can rebaseline without assuming an uninterrupted delta stream.
