# Device Lifecycle Spec Delta

## MODIFIED Requirements

### Requirement: Pinned engine and optional expansion
The mod SHALL target Factorio 2.1.23 and operate with base alone or with Space Age enabled. Expansion materials/technology MUST NOT be required by its base recipes. Ordinary radar modems SHALL work without Space Age; the advanced radar entity, item, recipe and technology SHALL exist only with Space Age enabled. Signal and device quality identities SHALL remain correct in both configurations. Dashboard labels/buttons SHALL require neither Space Age nor the optional chart library.

#### Scenario: Base-only installation
- **WHEN** the packaged mod is loaded with base and no expansion
- **THEN** prototypes load, devices can be unlocked/crafted and all applicable APIs work without missing expansion references
- **AND** ordinary radar communication works while no advanced-radar entity, item, recipe or research entry exists.

#### Scenario: Expansion installation
- **WHEN** the packaged mod is loaded with Space Age
- **THEN** both radar tiers are available through their intended progression, with no dependency on a planet-specific science pack.

#### Scenario: Optional dashboard charts
- **WHEN** either supported content configuration enables or omits the compatible factorio-charts dependency
- **THEN** dashboards load in both cases and only their chart capability depends on that library.

### Requirement: One-tier physical device family
The mod SHALL provide one tier of 1×1 computers, KV devices, monitor tiles and dashboards, 3×1 logic handlers and 2×1 configurators. Directional devices SHALL support cardinal rotation. Port roles SHALL be identifiable without relying solely on wire color. Dashboards SHALL have one passive computer-network connector and SHALL NOT merge into world-display walls.

#### Scenario: Place a rotated composite device
- **WHEN** a player or robot places a logic handler or configurator in any cardinal direction
- **THEN** its occupied footprint, visuals, selectable ports and wire endpoints match its logical roles.

#### Scenario: Place a dashboard
- **WHEN** a dashboard is placed or rotated next to another dashboard or monitor
- **THEN** it remains one independent 1×1 peripheral with correctly positioned native red/green network contacts.

### Requirement: Mining preserves user data
Mining SHALL preserve a computer's saved/active source snapshots, explicit state and label, a KV peripheral's contents/deadlines, and a dashboard's accepted layout and chart data, in bounded data-bearing items. Replacement SHALL create a new entity identity; computers SHALL be stopped. Runtime callbacks, queues, timers, subscriptions, viewer sessions and ownership MUST NOT travel in the item.

#### Scenario: Mine a working computer with unsaved editor changes
- **WHEN** mining is requested while a player's editor holds an unsaved draft
- **THEN** the draft remains recoverable in player UI storage and the item's committed snapshots remain unambiguous
- **AND** replacement does not auto-run the former program.

#### Scenario: Maximum accepted data is mined
- **WHEN** a device at its declared content capacity is mined
- **THEN** its snapshot including metadata fits the serialization/item limit without truncation or data loss.

#### Scenario: Replace a populated dashboard
- **WHEN** a player or robot mines and replaces a dashboard containing a wrapped rolling window and a bar dataset
- **THEN** the new identity retains that layout/data and no old computer binding, subscription, GUI session or render object is transferred
- **AND** restoration remains possible with the chart dependency absent.

### Requirement: Blueprint and clone isolation
Blueprints, entity clones and settings copy SHALL carry applicable source and configuration only, not computer runtime state, event registrations, KV contents, chart samples/bar datasets, output ownership or active execution. Newly created computers SHALL start stopped, databases empty and logic outputs zero. New dashboards SHALL copy tab/widget definitions but start with empty chart data and no subscribers or viewers.

#### Scenario: Blueprint a functioning controller
- **WHEN** its blueprint is built elsewhere
- **THEN** code and selected settings are available for inspection but the new computer does not configure the factory until explicitly run.

#### Scenario: Copy a dashboard configuration
- **WHEN** a populated dashboard is blueprinted, cloned or used as the source of settings copy
- **THEN** only layout, widget configuration and configured rolling capacities are copied, never source histories, bar datasets or computer subscriptions
- **AND** settings copy onto an existing dashboard follows ordinary tab-replacement compatibility rules for the destination's own chart data.

## ADDED Requirements

### Requirement: Dashboard physical identity and progression
The dashboard SHALL be a recognizable base-material control panel with a single data-bearing item and recipe unlocked through existing computer progression. Its icon, footprint, network contacts and power state SHALL agree with its native window identity. Existing device artwork and gameplay SHALL remain unchanged; added art SHALL retain reproducible provenance.

#### Scenario: Upgrade an already researched force
- **WHEN** the feature is installed in a force that already researched circuit computers
- **THEN** its dashboard recipe is available without rebuilding existing devices or researching an expansion technology.

#### Scenario: Inspect physical feedback
- **WHEN** a player selects, wires, rotates or marks the dashboard for deconstruction
- **THEN** its body, connector and native feedback remain legible and no internal helper appears as a separately buildable peripheral.
