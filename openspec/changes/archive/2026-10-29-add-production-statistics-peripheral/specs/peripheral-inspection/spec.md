# Peripheral Inspection Spec Delta

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
- **WHEN** an authorized player normally opens a powered or unpowered Factoriopedia Interface
- **THEN** the exact peripheral name is copyable and its type and availability are visible through the existing player-scoped inspector
- **AND** opening or refreshing performs no item/fluid catalogue enumeration, metadata query, world mutation or guest execution.

#### Scenario: Basic Production Statistics inspector
- **WHEN** an authorized player opens a powered or unpowered statistics device
- **THEN** its exact peripheral name remains selectable/copyable and its availability is explicit
- **AND** opening or refreshing the inspector performs no production-statistics queries, exposes no force/surface selector and executes no guest program.

#### Scenario: Open a configured dashboard
- **WHEN** an authorized player opens a Dashboard
- **THEN** its interactive mixed-tab window appears instead of a read-only inspector or carrier configuration dialog
- **AND** identity/status occupy the window shell rather than consuming one of its six configurable tabs.
