# peripheral-inspection delta

## MODIFIED Requirements

### Requirement: Native inspection for every peripheral family
The mod SHALL provide a device-local inspector for KV Database, Monitor, Logic Handler, Configurator, Recipe Searcher, Factoriopedia Interface and Production Statistics through normal entity opening.

#### Scenario: Family-specific opening surface
- **WHEN** the player normally opens a peripheral or computer
- **THEN** The window SHALL identify the logical device rather than a helper. Recipe Searcher, Factoriopedia Interface and Production Statistics SHALL receive basic identity/status inspection, not recipe-search, catalogue or statistics-query interfaces. Computers SHALL retain their existing workspace. A Dashboard SHALL instead open its configured interactive window, with the same exact copyable identity and explicit availability outside its user-configured tabs; it is not a read-only inspector.

#### Scenario: Open each peripheral
- **WHEN** an authorized player uses normal entity-open on any of these peripheral families
- **THEN** its inspector opens without exposing the carrier's native configuration controls
- **AND** no computer connection or running program is required to inspect the device locally.

#### Scenario: Existing device after upgrade
- **WHEN** a supported existing save is upgraded without replacing its peripherals
- **THEN** the same devices support ordinary inspector opening while retaining identities, wires, data and output ownership.

#### Scenario: Basic Factoriopedia Interface inspector
- **WHEN** an authorized player normally opens a Factoriopedia Interface with or without electrical coverage
- **THEN** the exact peripheral name is copyable and its type and availability are visible through the existing player-scoped inspector
- **AND** opening or refreshing performs no item/fluid catalogue enumeration, metadata query, world mutation or guest execution.

#### Scenario: Basic Production Statistics inspector
- **WHEN** an authorized player opens a statistics device with or without electrical coverage
- **THEN** its exact peripheral name remains selectable/copyable and its availability is explicit
- **AND** opening or refreshing the inspector performs no production-statistics queries, exposes no force/surface selector and executes no guest program.

#### Scenario: Open a configured dashboard
- **WHEN** an authorized player opens a Dashboard
- **THEN** its interactive mixed-tab window appears instead of a read-only inspector or carrier configuration dialog
- **AND** identity/status occupy the window shell rather than consuming one of its six configurable tabs.

### Requirement: Non-mutating inspection and explicit availability
Inspectors SHALL NOT execute guest code, edit data/configuration, create subscriptions, claim output ownership or alter display contents. Custom-device identity, KV contents, target inventories and live logic input queries SHALL require no electricity. Current identity, scope and access checks SHALL remain mandatory; unavailable details SHALL be labelled rather than represented as an empty successful result.

#### Scenario: Unpowered peripheral
- **WHEN** an authorized player opens a custom peripheral without electrical coverage
- **THEN** the name remains copyable and its normally supported details are available without an unpowered label
- **AND** actual validation failures remain explicit, retained data is not erased and stale snapshots are not presented as current.

#### Scenario: Browse without effects
- **WHEN** a player opens, selects, refreshes and closes an inspector
- **THEN** database values/deadlines, factory settings, output ownership, program state and monitor model revisions remain unchanged by inspection.

## ADDED Requirements

### Requirement: Open-session inspection scheduling
Recurring inspector refresh SHALL be limited to open authorized sessions at their existing bounded refresh cadence. Opening, closing, tab changes, invalidation and content updates SHALL maintain eligible work without scanning all devices or players to rediscover it. Inspection MUST NOT register guest signal subscriptions or grant stored observations as call authority.

#### Scenario: No open inspectors
- **WHEN** many inspectable peripherals exist with no open inspector
- **THEN** ordinary ticks do no inspector acquisition or UI work for those devices.

#### Scenario: Open Logic Handler without guest subscriptions
- **WHEN** an authorized player inspects live signals on a handler with no guest subscriber
- **THEN** that open session obtains bounded native observations independently; closing it leaves no watcher, while no computer is added to the signal-subscription work set.

#### Scenario: GUI pending or stale
- **WHEN** an open session cannot finish a bounded refresh or loses its original identity
- **THEN** existing pending/stale/unavailable presentation is preserved, and a replacement at the same coordinates is not silently adopted.
