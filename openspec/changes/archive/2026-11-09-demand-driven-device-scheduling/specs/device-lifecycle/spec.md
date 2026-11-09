# device-lifecycle delta

## MODIFIED Requirements

### Requirement: Base-game progression and queryable limits
Mod-built base devices SHALL build on circuit-network progression using base materials; ordinary radar modems SHALL retain vanilla radar progression without a new unlock. The optional advanced radar SHALL use its specified six-pack research. Recipe figures and unchanged native-radar power figures SHALL be documented before release; custom composite devices SHALL require no electricity. Resource and geometry limits SHALL be queryable and frozen only after the supported acceptance envelope is measured.

#### Scenario: Unsupported capacity is requested
- **WHEN** a player program exceeds a published device limit
- **THEN** it receives a documented refusal without corrupting accepted state or causing an unbounded simulation workload.

#### Scenario: Ordinary radar already craftable
- **WHEN** a force can already craft vanilla radar and has access to computers
- **THEN** it can use a locally wired radar as a modem without researching an additional ordinary-modem technology.

### Requirement: Blueprint and item continuity across shell changes
Existing blueprint, ghost and clone paths SHALL remain supported across a physical-shell change. Retired power helpers MUST NOT add user-visible costs or extra drops, and new placements MUST NOT create them. New placed computers SHALL remain stopped and blueprint copies MUST NOT acquire application state or KV contents. Existing non-computer data-bearing items SHALL retain their approved restoration behavior; legacy computer-item payloads SHALL follow the explicit discard policy.

#### Scenario: Use an older blueprint after upgrade
- **WHEN** a player builds a valid blueprint captured before the redesign
- **THEN** the intended devices, captured saved source/settings and role-specific wires are restored without requiring hidden helper items or duplicating application data.

#### Scenario: Replace a mined data-bearing device
- **WHEN** a computer or database item mined before the redesign is placed afterward
- **THEN** an ordinarily placed computer starts blank and stopped with a new identity despite any old item payload
- **AND** the database's approved contents and deadlines are restored under its existing item contract.

### Requirement: Dashboard physical identity and progression
The dashboard SHALL be a recognizable base-material control panel with a single data-bearing item and recipe unlocked through existing computer progression. Its icon, footprint, network contacts and operational status SHALL agree with its native window identity. Existing device artwork and gameplay SHALL remain unchanged; added art SHALL retain reproducible provenance.

#### Scenario: Upgrade an already researched force
- **WHEN** the feature is installed in a force that already researched circuit computers
- **THEN** its dashboard recipe is available without rebuilding existing devices or researching an expansion technology.

#### Scenario: Inspect physical feedback
- **WHEN** a player selects, wires, rotates or marks the dashboard for deconstruction
- **THEN** its body, connector and native feedback remain legible and no internal helper appears as a separately buildable peripheral.

### Requirement: Fresh operation-boundary monitor authority
Monitor operations SHALL retain their operation-specific identity, ownership, scope, geometry and circuit checks; electricity is not an availability condition. A prior observation or matching simulation tick SHALL NOT authorize a later operation after native state changes. Positive proof reuse SHALL be limited to a non-mutating operation scope; deferred work SHALL retain identities and revalidate them rather than retain reusable authority.

#### Scenario: Native changes within the same event
- **WHEN** an earlier check succeeds and native code then moves or rotates a tile, changes its force, removes an owned helper before a later check in the same event
- **THEN** the later guarded active operation or publication refuses the now-invalid state even though the simulation tick is unchanged
- **AND** restoring the state permits a fresh proof without requiring a tick advance; changing electricity alone does not invalidate a monitor.

#### Scenario: Retired identity still has queued work
- **WHEN** a monitor or selecting computer is removed, replaced or regrouped while presentation work is pending
- **THEN** that work cannot publish through the retired identity or affect an unrelated replacement
- **AND** owned cleanup completes under existing budgets while accepted surviving models remain recoverable.

#### Scenario: Idle Console selection loses its path
- **WHEN** a live Console-owned monitor selection has no ready frame and its selected wire path is definitively revoked while the saved program is stopped
- **THEN** the existing bounded authority maintenance detects and releases the selection with its existing diagnostic semantics, without waiting for a new drawing call
- **AND** a temporarily incomplete proof blocks rather than falsely detaches, and no alternative wire color is silently substituted.

### Requirement: Reliable monitor invalidation delivery
Accepted physical, settings and ownership transitions SHALL notify the affected monitor work before stale state can be published. Repeated notifications SHALL remain bounded by retained devices and work rather than event history. Budget refusal, further invalidation and save/reload SHALL NOT lose the need for reconciliation, visibility changes or cleanup.

#### Scenario: Supported lifecycle entry points
- **WHEN** placement, revival, clone, rotation, actual removal, settings paste, force merge or surface removal affects a monitor
- **THEN** the existing lifecycle handlers deliver the corresponding monitor invalidation without requiring a guest call or a periodic full signature sweep
- **AND** clone/item isolation, settings inheritance, helper ownership and removal guarantees remain unchanged.

#### Scenario: Deferred work followed by another change
- **WHEN** a monitor transition has scheduled reconciliation or cleanup but admission defers it and another relevant transition occurs
- **THEN** the newer invalidation remains represented until valid current state commits or owned cleanup completes
- **AND** repeated scheduling neither renews credits nor retains one work record per repeated event.

#### Scenario: Initialization and unsupported retained state
- **WHEN** upgrade introduces monitor observation metadata or retained metadata is unsupported
- **THEN** permitted synchronized initialization preserves existing state and valid unfinished work, while unsupported representations remain recoverable and cannot authorize unsafe operation
- **AND** ordinary load performs no world mutation, queue reconstruction, guest execution or native object creation.

## ADDED Requirements

### Requirement: Power-free custom composite devices
Computer, KV Database, Monitor, Logic Handler, Configurator, Recipe Searcher, Factoriopedia Interface, Production Statistics and Dashboard Interface SHALL consume no electricity and require no electrical supply. No active power helper or recurring electrical-availability tracking SHALL remain for these families. Both radar tiers and the native programmable speaker retain existing native electricity behavior.

#### Scenario: Every custom family outside electrical coverage
- **WHEN** each custom device is placed and used without any electrical network in base or Space Age
- **THEN** its ordinary services, Console, outputs, display, UI and controls work subject to non-power validation; no electric helper, drain or misleading low-power warning is created.

#### Scenario: Native exceptions
- **WHEN** an ordinary radar, advanced radar or programmable speaker is present
- **THEN** its existing energy source, consumption, scanning/audio/circuit behavior and native UI are unchanged; operation-time checks retain E_UNPOWERED where required.

#### Scenario: Power cycle with retained content
- **WHEN** the surrounding factory loses electricity while custom devices retain source, data, output and display state
- **THEN** the custom devices do not pause, blank, clear outputs, discard events or require restoration work merely because supply changed.

### Requirement: Demand-owned lifecycle maintenance
Lifecycle work SHALL be driven by native events, explicit dirty identities, outstanding repairs and due bounded observation. No full registry/device walk SHALL be used to discover ordinary per-tick work. Idle physical observations may be staggered within the existing topology latency envelope; active signal observation and output fail-safe deadlines MUST NOT be weakened.

#### Scenario: Settled idle devices
- **WHEN** valid custom devices have no pending repair or interaction
- **THEN** they receive no per-tick physical or power sweep; due low-frequency physical observation is separately measured and does not rebuild an all-device work list each tick.

#### Scenario: Silent physical change
- **WHEN** a script changes position, direction, force, surface or helper validity without a usable immediate event
- **THEN** fresh calls reject stale authority immediately and bounded due observation schedules affected repair/grouping/status work within the existing topology envelope; output owners retain the stricter fail-safe envelope.

#### Scenario: Destruction registration
- **WHEN** a tracked body or helper disappears without an ordinary raised removal event
- **THEN** targeted destruction handling retires or repairs its exact identity without scanning dormant records or deleting an unrelated replacement.

#### Scenario: Dirty work survives deferral
- **WHEN** clone, undo, native adoption, monitor grouping or physical repair is deferred
- **THEN** only pending/due work retains membership and paid progress; repeated notifications coalesce, and idle systems do not keep polling after their work completes.

#### Scenario: All maintenance classes accounted for
- **WHEN** recurring lifecycle and presentation hooks are exercised
- **THEN** each visit is attributable to a pending item, due deadline or active observer; no fallback universal loop remains under a different hook name.

### Requirement: Upgrade without power-helper or scheduling data loss
A versioned synchronized upgrade SHALL retire owned legacy power helpers and initialize scheduling membership before ordinary ticks. It SHALL preserve identities, real role wires, source/state, accepted queues, timer deadlines, subscriptions, database data, display models and spent credits. Unsupported saved state SHALL remain recoverable rather than silently reset.

#### Scenario: Upgrade a formerly powered device family
- **WHEN** an old save containing every custom family and native radar/speaker endpoints upgrades
- **THEN** only positively owned electrical helpers are removed without drops; bodies, role sockets, wires and retained content survive; native endpoints remain untouched.

#### Scenario: Legacy paused run
- **WHEN** a previously running computer was electrically paused when saved
- **THEN** upgrade removes the electrical pause without invoking startup or inventing a new run; retained timers coalesce normally and surviving signal subscriptions receive a current resync if their legacy state requires it; already discarded transients are not resurrected.

#### Scenario: Stopped faulted and unsupported records
- **WHEN** an old save contains intentionally stopped/faulted computers or unsupported headers
- **THEN** upgrade does not start them or overwrite recoverable data; unknown authority cannot become executable simply by creating scheduling membership.

#### Scenario: Legacy blueprints and item paths
- **WHEN** a pre-change blueprint, clone or retained data-bearing item is restored
- **THEN** new placements use no power helper, preserve existing source/item isolation contracts and role wiring, and produce no extra items or shared identities.

#### Scenario: Ordinary cold load after migration
- **WHEN** the migrated save loads in a different process or on a joining peer
- **THEN** load callbacks execute no source and mutate no authoritative queues/world state; ordinary ticks use retained membership without repeating an all-device migration.

## REMOVED Requirements

### Requirement: Electricity and passive wire continuity
**Reason**: Custom devices intentionally no longer require electricity.
**Migration**: Apply Power-free custom composite devices and the upgrade requirement; passive topology and durable expiry remain unchanged.

### Requirement: Consolidated live monitor observation
**Reason**: Every-tick idle monitor physical/power polling is superseded by demand-owned work and accepted bounded idle observations.
**Migration**: Retain fresh operation-boundary identity/geometry/ownership proofs, output-safety checks and targeted invalidation. Electrical outages no longer hide monitors; unchanged neighboring custom families also become power-free while native exceptions retain their power.
