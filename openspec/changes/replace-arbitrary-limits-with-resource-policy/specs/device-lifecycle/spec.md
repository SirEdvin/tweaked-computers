## MODIFIED Requirements

### Requirement: Mining preserves user data
Mining SHALL preserve a computer's saved/active source snapshots, explicit state and label, and a KV peripheral's contents/deadlines, in a data-bearing item under aggregate resource accounting without an independent transport-size ceiling. Replacing that item SHALL create a new entity identity in a stopped state. Runtime callbacks, suspended invocations, queues, timers and ownership MUST NOT travel in the item.

#### Scenario: Mine a working computer with unsaved editor changes
- **WHEN** mining is requested while a player's editor holds an unsaved draft
- **THEN** the draft remains recoverable in player UI storage and the item's committed snapshots remain unambiguous
- **AND** replacement does not auto-run the former program.

#### Scenario: Maximum accepted data is mined
- **WHEN** a device at its accepted content capacity, including grandfathered data above a lowered setting is mined
- **THEN** its snapshot including metadata is preserved completely under actual engine serialization constraints without truncation or data loss.

### Requirement: Save and migration integrity
Ordinary saves SHALL preserve complete live state, data, deadlines, ownership and unfinished continuation/service progress. Schema changes SHALL migrate on permitted synchronized lifecycle stages, never during read-only load. Unsupported/corrupt representations SHALL preserve recoverable user data and refuse unsafe activation.

#### Scenario: Cold save/load
- **WHEN** the packaged mod saves a running factory and another process reloads it
- **THEN** identities, data, current display, timers and active source remain consistent without duplicate startup effects.

### Requirement: Base-game progression and queryable limits
Mod-built base devices SHALL build on circuit-network progression using base materials; ordinary radar modems SHALL retain vanilla radar progression without a new unlock. The optional advanced radar SHALL use its specified six-pack research. Power/recipe figures SHALL be explicit balance settings documented before release. Remaining resource and KV limits SHALL be configurable/queryable under resource-policy; monitor geometry SHALL retain its six-tile ceiling. Defaults SHALL be measured before release.

#### Scenario: Unsupported capacity is requested
- **WHEN** a player program exceeds a published device limit
- **THEN** it receives a documented recoverable refusal or resumable waiting state without corrupting accepted state or causing an unbounded simulation workload.

#### Scenario: Ordinary radar already craftable
- **WHEN** a force can already craft vanilla radar and has access to computers
- **THEN** it can use a locally wired radar as a modem without researching an additional ordinary-modem technology.

### Requirement: Non-invasive native radar lifecycle
Adopting a supported native radar SHALL NOT replace its body, add power/socket helpers, rewrite native power/scanning settings, suppress native interaction, or alter its drops. Placement, removal, clone, revival and scope changes SHALL reconcile modem identity without applying composite-shell conversion. Integration failure SHALL preserve the native entity and unrelated wires.

#### Scenario: Native build and mine
- **WHEN** a player or robot builds and mines an ordinary radar
- **THEN** modem registration and cleanup occur without extra items, helper entities, duplicate drops or modifications to vanilla scanning/circuit behavior.

#### Scenario: Registration capacity is full
- **WHEN** a placed or existing radar cannot be registered because configured host resource admission is unavailable
- **THEN** it remains an intact native radar and modem unavailability is reported explicitly, rather than destroying/refunding it or publishing a functioning partial integration.

## ADDED Requirements

### Requirement: No fixed world device count
Device registration, running computers, output owners, subscriptions, Console sessions and placed monitor tiles SHALL have no independent world-count ceilings. Host bookkeeping SHALL use configurable aggregate resource accounting and fair incremental work. Native entities SHALL remain intact if integration is pending or resource-refused.

#### Scenario: Factory exceeds former world counts
- **WHEN** a factory exceeds 64 running computers, 128 logic owners or 256 monitor tiles with adequate configured resources
- **THEN** existing and new devices remain functional under fair scheduling without those fixed-count refusals.

### Requirement: Continuation ABI migration without replay
An upgrade SHALL convert supported legacy waiting runs, queues, timers, ownership and shell values to the new versioned runtime during synchronized lifecycle work. It SHALL preserve active/saved source distinctions and not replay startup. Unsupported continuation representations SHALL retain recoverable data and report incompatibility without executing it.

#### Scenario: Upgrade a waiting legacy controller
- **WHEN** a supported legacy save has pending timers and output ownership but no suspended stack
- **THEN** migration preserves its run identity, data and pending work, creates no fabricated stack and does not repeat completed writes.

#### Scenario: Clone a suspended computer
- **WHEN** a suspended computer is cloned or blueprint-built elsewhere
- **THEN** the new entity remains stopped with only approved source/configuration, not its continuation, heap or runtime ownership.
