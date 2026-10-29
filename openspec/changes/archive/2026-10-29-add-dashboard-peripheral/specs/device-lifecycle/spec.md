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

### Requirement: Device-specific mining data policy
Mining a computer SHALL produce plain hardware without source snapshots, explicit application state or a computer label.

#### Scenario: Family-specific retained item contents
- **WHEN** a device is mined, replaced or restored through Undo
- **THEN** Ordinary replacement SHALL create a blank, stopped computer with a new identity. KV items SHALL retain contents and absolute deadlines, and monitor items SHALL retain their existing settings. Dashboard items SHALL retain accepted layout and chart data. Runtime callbacks, queues, timers and ownership MUST NOT travel in items. Undo restoration SHALL use the separate undo contract.

#### Scenario: Mine a working computer with unsaved editor changes
- **WHEN** mining is requested while a player's editor holds an unsaved draft
- **THEN** the draft remains recoverable in player UI storage under its original identity, and the computer item contains no committed source/state snapshot
- **AND** ordinary replacement starts blank and stopped without adopting the old draft.

#### Scenario: Maximum accepted data is mined
- **WHEN** a device at its declared content capacity is mined
- **THEN** a computer still produces plain hardware, with any qualifying undo snapshot governed by the undo retention requirements
- **AND** devices whose contents travel in items retain their complete approved snapshot including metadata without truncation or data loss.

#### Scenario: Ordinary replacement is independent of the item history
- **WHEN** a freshly crafted or newly mined computer item is placed without a blueprint or qualifying undo restoration
- **THEN** the new computer has empty saved source and application state, no computer label, and no active execution
- **AND** its previous location and any earlier computer identity are not used to recover contents automatically.

#### Scenario: Robot and platform item transport
- **WHEN** player, robot or space-platform construction consumes a computer item after ordinary removal
- **THEN** the same plain-item policy applies without a hidden computer snapshot or an extra drop
- **AND** KV deadlines and monitor item settings remain governed by their unchanged family-specific policies.

#### Scenario: Replace a populated dashboard
- **WHEN** a player or robot mines and replaces a dashboard containing a wrapped rolling window and a bar dataset
- **THEN** the new identity retains that layout/data and no old computer binding, subscription, GUI session or render object is transferred
- **AND** restoration remains possible with the chart dependency absent.

### Requirement: Blueprint and clone isolation
Blueprints, clipboard copies, entity clones and settings copy SHALL carry applicable saved source, label and configuration only, not computer application state, event registrations, KV contents, output ownership or active execution.

#### Scenario: Copied device initialization
- **WHEN** a blueprint, clipboard, clone or settings-copy operation creates or updates a device
- **THEN** Newly created computers SHALL start stopped, databases empty and logic outputs zero. Computer item contents MUST NOT override the captured source/settings. Existing-destination settings copy SHALL retain its existing state policy. New dashboards SHALL copy definitions but start with empty charts and no subscribers or viewers.

#### Scenario: Blueprint a functioning controller
- **WHEN** its blueprint is built elsewhere
- **THEN** the captured saved code and selected settings are available for inspection but the new computer does not configure the factory until explicitly run.

#### Scenario: Native clipboard copy onto empty ground
- **WHEN** a player saves a program, selects the computer with Ctrl+C and places it onto empty ground with Ctrl+V
- **THEN** the completed computer contains the exact saved source and label captured at copy time, with empty application state and no runtime work
- **AND** the result is identical for fresh, previously mined and legacy-tagged computer construction items.

#### Scenario: Delayed ghost construction
- **WHEN** a source-bearing copied ghost is built later, including by a robot or after a save/load
- **THEN** the completed computer receives that ghost's captured source/settings exactly once, with the correct role-specific wires and no automatic startup
- **AND** later edits or removal of the original computer do not change the captured source.

#### Scenario: Draft and running source differ from saved source
- **WHEN** a copied computer has different saved source, formerly active source and a player's unsaved draft
- **THEN** the copy carries only the saved source and label
- **AND** neither the draft, formerly active source nor explicit application state is substituted for the saved source.

#### Scenario: Clone and settings-copy regressions
- **WHEN** a computer is cloned or its settings are copied onto an existing computer
- **THEN** a clone receives a new stopped identity with copied saved source and empty application state
- **AND** settings copy stops the destination and replaces saved source/label without copying source application state or erasing the destination's existing application state.

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
