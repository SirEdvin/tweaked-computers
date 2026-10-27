# Peripheral Inspection Spec Delta

## MODIFIED Requirements

### Requirement: Native inspection for every peripheral family
The mod SHALL provide a device-local inspector for KV Database, Monitor, Logic Handler, Configurator, Recipe Searcher and Production Statistics through normal entity opening. The window SHALL identify the logical device rather than a helper. Recipe Searcher and Production Statistics SHALL receive basic identity/status inspection, not recipe-search or statistics-query interfaces. Computers SHALL retain their existing workspace.

#### Scenario: Open each peripheral
- **WHEN** an authorized player uses normal entity-open on any of the six peripheral families
- **THEN** its inspector opens without exposing the carrier's native configuration controls
- **AND** no computer connection or running program is required to inspect the device locally.

#### Scenario: Existing device after upgrade
- **WHEN** a supported existing save is upgraded without replacing its peripherals
- **THEN** the same devices support ordinary inspector opening while retaining identities, wires, data and output ownership.

#### Scenario: Basic Production Statistics inspector
- **WHEN** an authorized player opens a powered or unpowered statistics device
- **THEN** its exact peripheral name remains selectable/copyable and its availability is explicit
- **AND** opening or refreshing the inspector performs no production-statistics queries, exposes no force/surface selector and executes no guest program.
