# Peripheral Inspection Specification Delta

## MODIFIED Requirements

### Requirement: Native inspection for every peripheral family
The mod SHALL provide a device-local inspector for KV Database, Monitor, Logic Handler, Configurator, Recipe Searcher and Factoriopedia Interface through normal entity opening. The window SHALL identify the logical device rather than a helper. Recipe Searcher and Factoriopedia Interface SHALL receive basic identity/status inspection, not recipe-search or catalogue interfaces. Computers SHALL retain their existing workspace.

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
