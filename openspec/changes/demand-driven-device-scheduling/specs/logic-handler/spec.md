# logic-handler delta

## MODIFIED Requirements

### Requirement: Tick-sampled change subscriptions
Programs SHALL subscribe named handlers to explicit red or green inputs, optionally filtered by identity. Subscription-count limits SHALL be checked only when the user registers. Accepted subscriptions SHALL observe native inputs each simulation tick without internal inventory ceilings or persisted processing jobs. Only changes, requested initial observations or resynchronization SHALL emit events. A fresh native change indication may avoid an unchanged inventory read, but MUST NOT skip connectivity checks or initial/resync observations. Comparisons SHALL use effective identities and counts, not order.

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

### Requirement: Last-writer authority and fail-safe cleanup
The output set SHALL record its last successful writer's computer identity, run generation and access channel. Stop, fault, invalidation or loss of that writer's access SHALL clear its still-owned output. Cleanup MUST run independently of user callbacks.

#### Scenario: A newer writer remains authoritative
- **WHEN** computer A writes, computer B overwrites, and A then stops
- **THEN** B's output remains intact.

#### Scenario: Last writer loses its cable
- **WHEN** the selected same-color path of the current writer becomes invalid
- **THEN** the handler clears the owned output within the published fail-safe reconciliation envelope, even if the writer ignores its detach event.

### Requirement: Own output contribution rather than network totals
The Output signals area SHALL show the handler's own emitted bank, with an explicit label that it is shared across its red and green output wires. It SHALL NOT attribute signals from other emitters on an output network to this handler. Inspection SHALL NOT write a bank, claim ownership or change fail-safe cleanup behavior.

#### Scenario: Another emitter shares the output wire
- **WHEN** an unrelated device emits signals onto a network connected to the handler's output
- **THEN** the inspector shows only this handler's contribution, not the combined output-network totals.

#### Scenario: Writer or handler loses authority or power
- **WHEN** existing fail-safe reconciliation clears the handler's output after authority loss (electrical changes alone no longer clear it)
- **THEN** the next successful inspector update shows the cleared bank without replaying a write or restoring the former owner.

### Requirement: Bounded live signal observation
Signal trays SHALL appear before refresh and query native inputs and own output directly, independently of subscriptions. No native inventory SHALL be rejected or truncated by mod size ceilings. Refresh scheduling and presentation SHALL preserve responsiveness without caching service reads or adding persisted sampling/sorting/validation jobs. Separate-tick observations SHALL remain distinguishable; closing inspection SHALL not affect subscriptions or output ownership.

#### Scenario: Signals change with the inspector open
- **WHEN** inputs change and the inspector refreshes
- **THEN** it displays fresh native observations without reopening or altering subscriptions.

#### Scenario: Query exceeds supported signal capacity
- **WHEN** a native input exceeds 64 or 1,024 signals
- **THEN** every signal remains accessible in the inspector, not a capacity error, hidden tail or apparently complete prefix.

#### Scenario: One input cannot be sampled
- **WHEN** an input is genuinely unavailable while the other input and own output remain available
- **THEN** all trays stay visible, the unavailable input is marked honestly and the other regions continue updating
- **AND** retained presentation state is never returned as a fresh service read or mistaken for an empty successful sample.

## ADDED Requirements

### Requirement: Subscription-owned observation membership
Only inputs with active accepted subscriptions SHALL receive recurring subscription observation. Membership SHALL change with registration, cancellation, run retirement and endpoint invalidation, not by rediscovering subscriptions across all computers every tick. One physical input/color observation SHALL serve its subscribers with independent filters and isolated delivery.

#### Scenario: Many computers without subscriptions
- **WHEN** computers run timers, receive messages or remain idle without signal subscriptions
- **THEN** none receives a signal-work discovery or subscription-sampling visit merely because it exists or is running.

#### Scenario: One-tick native pulse
- **WHEN** an actively subscribed input changes for one observable circuit step within the supported envelope
- **THEN** that change is observed at tick-level responsiveness even when its computer is waiting or has queued callbacks; callback dispatch latency remains separately bounded.

#### Scenario: Shared connector and separate colors
- **WHEN** multiple subscriptions use one physical input/color and another subscription uses the other color
- **THEN** the common native observation is shared without merging red/green, selected-wire authority, independent filters or previous observations.

#### Scenario: Last subscriber leaves
- **WHEN** the last subscription for an input/color is canceled or retired
- **THEN** that input leaves recurring subscription work immediately; queued canceled notifications cannot run and no dormant polling remains.

#### Scenario: Initial resync and false-positive change flag
- **WHEN** an initial/resync observation is owed or a native change hint is spuriously true
- **THEN** required observations still occur and actual effective values/connectivity decide ordinary change delivery, not the hint alone.

#### Scenario: Insufficient sample admission
- **WHEN** the supported tick observation cannot be completed under current bounds
- **THEN** affected runs follow the existing explicit sampling-failure/fault cleanup rather than silently skipping a pulse, inventing unchanged input or switching to slower polling.

### Requirement: Electricity-independent logic service
Logic Handler reads, subscriptions and outputs SHALL operate without electricity. Factory power changes SHALL neither erase a valid output bank nor manufacture a signal resync. Physical identity, input roles, selected-wire authority and last-writer fail-safe rules SHALL remain enforced.

#### Scenario: No power network
- **WHEN** a valid computer and Logic Handler are wired together outside electrical coverage
- **THEN** reads, subscriptions and native output replacement work normally with isolated input/network/output roles.

#### Scenario: Native factory signal changes during outage
- **WHEN** an external powered producer loses supply while the mod-built handler remains valid
- **THEN** any resulting native signal change is observed normally; the handler itself does not enter a power-paused state.

## REMOVED Requirements

### Requirement: Input and network power policy
**Reason**: Electrical availability is no longer a condition of a custom Logic Handler.
**Migration**: Keep accepted baselines and ownership; migration may request one current-input resync for an already paused legacy registration, but ordinary electrical changes no longer do so.
