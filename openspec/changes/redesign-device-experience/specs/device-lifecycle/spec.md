# Device lifecycle redesign delta

Baseline: corresponding capability in `add-native-circuit-computers`; unchanged power, progression, mining snapshots, blueprint isolation and save/load requirements continue to apply. This change does not authorize archiving or weakening unverified client requirements.

## MODIFIED Requirements

### Requirement: Coherent composite lifecycle
A composite device SHALL place, rotate, mine, destroy, clone and revive as one logical item. Owned helper entities MUST NOT yield duplicate drops, survive as usable orphans, steal another device's identity or destroy a replacement occupying an old position. Selection, opening and deconstruction SHALL identify the logical device, with auxiliary sockets confined to their explicit role rather than presenting a generic NETWORK tile.

#### Scenario: Partial placement failure
- **WHEN** a required component cannot be created
- **THEN** placement fails or rolls back without consuming an extra item, leaving a functioning partial device or deleting unrelated entities.

#### Scenario: Robot removal
- **WHEN** a robot mines a composite device
- **THEN** all owned parts are removed and exactly one logical item is produced with the approved data snapshot.

#### Scenario: Deconstruct a device through its footprint
- **WHEN** the player marks a device for deconstruction
- **THEN** the logical device receives the order, its marker is visible and internal parts cannot remain as independently usable devices after removal.

### Requirement: Attributable adapted artwork
Devices SHALL use the distinct Factorio-industrial visual family defined by `device-visual-identity`. Original authored artwork is preferred; any retained approved Greg Flavored input SHALL retain its pinned provenance and MIT notices. Runtime sprites SHALL match Factorio perspective, rotations, shadows, status and connectors. Known unresolved provenance SHALL block only the affected asset, not unrelated authored work.

#### Scenario: Asset release audit
- **WHEN** a distributable archive is built
- **THEN** every shipped derived asset has identified inputs, hashes, transformation record and required notices
- **AND** the promotional preview image is not substituted for a verified entity sprite set.

## ADDED Requirements

### Requirement: Existing-alpha interaction migration
An upgrade from the published alpha SHALL preserve recoverable player drafts, source/state, KV contents/deadlines, display state and valid physical wires when changing device carriers. Logical identity SHALL not be silently reassigned to an unrelated entity. Unsupported conversion SHALL retain recoverable data and refuse unsafe operation rather than silently rebuilding empty devices.

#### Scenario: Upgrade a populated controller network
- **WHEN** a saved alpha 0.1.1 world with red/green connections, programs, KV data and a monitor is upgraded
- **THEN** the devices expose the redesigned interaction while retained data and wire roles remain correct, without duplicate startup effects or newly bridged roles.

#### Scenario: Conversion cannot complete
- **WHEN** replacement or wire restoration fails
- **THEN** recoverable data is retained and the affected device is explicitly unavailable instead of losing its source, silently dropping wires or activating a partially converted controller.

### Requirement: Blueprint and item continuity across shell changes
Existing blueprint, ghost, clone and data-bearing item paths SHALL remain supported across a physical-shell change. Internal power helpers MUST NOT add user-visible costs or extra drops. New placed computers SHALL retain the existing stopped-state rule and blueprint copies MUST NOT acquire runtime state or KV contents.

#### Scenario: Use an older blueprint after upgrade
- **WHEN** a player builds a valid blueprint captured before the redesign
- **THEN** the intended devices and role-specific wires are restored without requiring hidden helper items or duplicating application data.

#### Scenario: Replace a mined data-bearing device
- **WHEN** a computer or database item mined before the redesign is placed afterward
- **THEN** its approved data snapshot is restored and the new entity follows the existing identity and stopped-state rules.
