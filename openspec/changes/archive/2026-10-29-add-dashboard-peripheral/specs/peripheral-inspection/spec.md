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

### Requirement: Inspection and existing gestures remain distinct
Normal peripheral opening SHALL inspect, or open a Dashboard's configured window, rather than emit a monitor touch.

#### Scenario: Existing gestures and recovery access
- **WHEN** the player uses device opening, Ctrl-click, transfer, rotation or draft recovery
- **THEN** Ctrl-click monitor touches, guarded Ctrl-click computer-body editing, native inventory transfers and cardinal rotation SHALL retain their existing behavior. Empty-ground clicks SHALL NOT open computer UI, even with retained drafts. Draft recovery SHALL remain accessible through another computer's Maintenance or the capacity viewer when opening a computer with all draft slots occupied. Owned helper dialogs SHALL remain inaccessible, and unrelated entity windows SHALL NOT be replaced.

#### Scenario: Inspect then touch a monitor
- **WHEN** a player normally opens a monitor, closes the inspector and then Ctrl-clicks a valid display cell
- **THEN** opening produces no touch, and the later Ctrl-click produces the existing authorized touch behavior without opening an inspector.

#### Scenario: Existing computer and native controls
- **WHEN** a player Ctrl-clicks a computer, rotates a peripheral or uses Ctrl with vanilla inventory controls
- **THEN** those actions keep their established behavior without duplicate rotation, lost drafts or an unwanted peripheral window.

#### Scenario: Dashboard buttons do not replace native gestures
- **WHEN** a player opens/closes a Dashboard or changes its selected tab without activating a button
- **THEN** no button or monitor-touch event is emitted
- **AND** subsequently opening another machine closes the dashboard session without the dashboard reopening over it.
