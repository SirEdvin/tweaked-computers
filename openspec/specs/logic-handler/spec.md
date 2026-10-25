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
The API SHALL require explicit red or green input selection. Each read SHALL query that native input directly, without a signal cache, mod inventory ceiling, sorting, normalization, reaggregation or validation of engine-produced values. Collections SHALL preserve native order, fields and signal categories, with no ordering guarantee. Missing signals SHALL read as zero; no signals SHALL return an empty array. Returned tables SHALL not expose mutable host state.

#### Scenario: Same item at different qualities
- **WHEN** normal and higher-quality item signals exist together
- **THEN** they remain distinct in reads, filters, output and change notifications.

#### Scenario: Red and green isolation
- **WHEN** both physical input colors are connected and a caller selects red or green
- **THEN** only that color's native signed-32-bit values are returned; selecting both or omitting the selector fails without registration or mutation.

#### Scenario: Unrelated prototype catalogue grows
- **WHEN** installed mods add unrelated prototypes without changing the selected input
- **THEN** reads query the selected input rather than scanning the prototype catalogue to calculate an admission envelope.

#### Scenario: Native records replace canonical records
- **WHEN** native results omit default identity fields or return signals in a different order
- **THEN** reads preserve those records without filling defaults or sorting
- **AND** item, fluid, virtual, recipe, entity and expansion-specific categories returned by the engine are not rejected by a mod-maintained read whitelist.

#### Scenario: Fresh reads exceed former ceilings
- **WHEN** an input carries 65, 150 or more than 1,024 signals and changes between calls
- **THEN** each call returns its complete current native result, including entries beyond former boundaries, not an older subscription or inspector observation
- **AND** signal names accepted by the engine are not rejected for exceeding the mod's identifier length.

### Requirement: Shared combinator-style output
The handler SHALL broadcast one output set identically on red and green. Writes SHALL validate caller data and replace the bank atomically within native domains, without mod signal-count/name ceilings or sorting. Native optional identity fields SHALL be accepted. Own-output reads SHALL query its native configuration, not cached values or network totals. Failed replacement SHALL preserve the previous bank and writer, subject to existing engine-failure recovery.

#### Scenario: Output is visible on either wire color
- **WHEN** an authorized computer successfully replaces the output set
- **THEN** red and green output networks receive the same contribution through Factorio's native circuit update behavior.

#### Scenario: Rejected output remains unchanged
- **WHEN** a write contains duplicate effective identities, an invalid prototype/quality, an out-of-range count or exceeds native capacity
- **THEN** the previous output and writer ownership remain unchanged.

#### Scenario: Native-size replacement and own-output readback
- **WHEN** a valid bank exceeding 64 entries fits the native output section and another emitter shares its output wire
- **THEN** the whole replacement succeeds and readback contains only this handler's contribution, without canonical ordering or injected default fields.

#### Scenario: Native defaults remain valid caller input
- **WHEN** a caller supplies an item identity with omitted type or normal quality, including a record obtained from a native read
- **THEN** validation interprets native defaults without requiring an expanded record
- **AND** identities differing only by explicit versus omitted defaults are duplicates, not independent outputs.

### Requirement: Tick-sampled change subscriptions
Programs SHALL subscribe named handlers to explicit red or green inputs, optionally filtered by identity. Subscription-count limits SHALL be checked only when the user registers. Accepted subscriptions SHALL sample native inputs each powered simulation tick without internal inventory ceilings or persisted processing jobs. Only changes, requested initial observations or resynchronization SHALL emit events. Comparisons SHALL use effective identities and counts, not order.

#### Scenario: Unchanged input
- **WHEN** consecutive selected input snapshots and connectivity are identical, possibly with different array ordering or omitted versus explicit default fields
- **THEN** no redundant change event is emitted.

#### Scenario: Signal disappears
- **WHEN** a previously nonzero subscribed signal becomes absent
- **THEN** the event includes its previous value and a current value of zero, not merely a list omitting it.

#### Scenario: Input connection changes without values
- **WHEN** an empty input network is disconnected
- **THEN** the subscription distinguishes the connectivity change from a still-connected zero-valued input.

#### Scenario: Admission happens at registration only
- **WHEN** a user exceeds the existing per-computer or aggregate subscription-count allowance
- **THEN** registration fails before adding a subscription or changing existing baselines
- **AND** accepted subscriptions are not re-admitted or retired because of that refusal, signal growth or a distinct sampled-device count.

#### Scenario: Large filters and complete event delivery
- **WHEN** an accepted subscription observes or filters more than 1,024 valid identities and its event queue has backlog capacity
- **THEN** its baseline and delivered previous/current/changes arrays contain all applicable entries, without a filter-count, generic Data or per-event signal-size rejection
- **AND** native records remain unnormalized and unsorted throughout delivery.

#### Scenario: Retained observations are not a read cache
- **WHEN** previous observations or undispatched events exist
- **THEN** they serve comparison and delivery only; a direct read or new registration baseline queries the native input independently
- **AND** callback mutation cannot change another subscriber's event or the next comparison baseline.

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
Signal slots SHALL display effective native identity and exact signed count, interpreting omitted defaults at presentation without rewriting records. All engine-produced categories SHALL remain inspectable. Disconnected, connected-empty and unavailable inputs SHALL remain distinguishable. Presentation SHALL NOT introduce a sorting or complete-field guarantee for the API.

#### Scenario: Quality and namespace distinctions
- **WHEN** normal and higher-quality items, or an item and recipe with the same name, appear together
- **THEN** they remain separate entries with unambiguous identity details and appropriate native icons where available.

#### Scenario: Negative or large values
- **WHEN** a signal has a negative count or a value near a signed-32-bit boundary
- **THEN** its exact value remains accessible in details/tooltips.

#### Scenario: Empty versus disconnected
- **WHEN** one input is connected with no signals and the other is disconnected
- **THEN** the input region distinguishes those states without fabricated zero entries or treating a failed query as empty.

### Requirement: Own output contribution rather than network totals
The Output signals area SHALL show the handler's own emitted bank, with an explicit label that it is shared across its red and green output wires. It SHALL NOT attribute signals from other emitters on an output network to this handler. Inspection SHALL NOT write a bank, claim ownership or change fail-safe cleanup behavior.

#### Scenario: Another emitter shares the output wire
- **WHEN** an unrelated device emits signals onto a network connected to the handler's output
- **THEN** the inspector shows only this handler's contribution, not the combined output-network totals.

#### Scenario: Writer or handler loses authority or power
- **WHEN** existing fail-safe reconciliation clears the handler's output
- **THEN** the next successful inspector update shows the cleared bank without replaying a write or restoring the former owner.

### Requirement: Bounded live signal observation
Signal trays SHALL appear before refresh and query native inputs and own output directly, independently of subscriptions. No native inventory SHALL be rejected or truncated by mod size ceilings. Refresh scheduling and presentation SHALL preserve responsiveness without caching service reads or adding persisted sampling/sorting/validation jobs. Separate-tick observations SHALL remain distinguishable; closing inspection SHALL not affect subscriptions or output ownership.

#### Scenario: Signals change with the inspector open
- **WHEN** powered inputs change and the inspector refreshes
- **THEN** it displays fresh native observations without reopening or altering subscriptions.

#### Scenario: Query exceeds supported signal capacity
- **WHEN** a native input exceeds 64 or 1,024 signals
- **THEN** every signal remains accessible in the inspector, not a capacity error, hidden tail or apparently complete prefix.

#### Scenario: One input cannot be sampled
- **WHEN** an input is genuinely unavailable while the other input and own output remain available
- **THEN** all trays stay visible, the unavailable input is marked honestly and the other regions continue updating
- **AND** retained presentation state is never returned as a fresh service read or mistaken for an empty successful sample.
