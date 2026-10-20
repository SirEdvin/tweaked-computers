# device-lifecycle Specification

## Purpose

Make programmable devices behave as coherent Factorio entities with correct placement, wiring, electricity, save persistence, recoverable mined data and attributable artwork.

## Requirements

### Requirement: Pinned engine and optional expansion
The mod SHALL target Factorio 2.0.77 and operate with base alone or with Space Age enabled. Expansion materials/technology MUST NOT be required by its base recipes. Signal and device quality identities SHALL remain correct in both configurations.

#### Scenario: Base-only installation
- **WHEN** the packaged mod is loaded with base and no expansion
- **THEN** prototypes load, devices can be unlocked/crafted and all applicable APIs work without missing expansion references.

### Requirement: One-tier physical device family
The mod SHALL provide one tier of 1×1 computers, KV devices and monitor tiles, 3×1 logic handlers and 2×1 configurators. Directional devices SHALL support cardinal rotation. Port roles SHALL be identifiable without relying solely on wire color.

#### Scenario: Place a rotated composite device
- **WHEN** a player or robot places a logic handler or configurator in any cardinal direction
- **THEN** its occupied footprint, visuals, selectable ports and wire endpoints match its logical roles.

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

### Requirement: Electricity and passive wire continuity
Devices SHALL require electrical power for active services. Power loss SHALL pause computers, blank monitors without erasing buffers, refuse active KV/configurator services and clear logic output. Stored data and expiry deadlines SHALL remain durable; passive wire/discovery topology SHALL not depend on power.

#### Scenario: Powered computer reaches an unpowered database
- **WHEN** discovery finds a physically connected database without power
- **THEN** its identity and unpowered status remain inspectable but data operations report an explicit unpowered error.

### Requirement: Mining preserves user data
Mining SHALL preserve a computer's saved/active source snapshots, explicit state and label, and a KV peripheral's contents/deadlines, in a bounded data-bearing item. Replacing that item SHALL create a new entity identity in a stopped state. Runtime callbacks, queues, timers and ownership MUST NOT travel in the item.

#### Scenario: Mine a working computer with unsaved editor changes
- **WHEN** mining is requested while a player's editor holds an unsaved draft
- **THEN** the draft remains recoverable in player UI storage and the item's committed snapshots remain unambiguous
- **AND** replacement does not auto-run the former program.

#### Scenario: Maximum accepted data is mined
- **WHEN** a device at its declared content capacity is mined
- **THEN** its snapshot including metadata fits the serialization/item limit without truncation or data loss.

### Requirement: Destruction and surface deletion
Destruction SHALL remove the destroyed device's data, handles, owned render objects and pending work. Surface deletion and force changes SHALL reconcile device registries and authority without transferring data to unrelated entities.

#### Scenario: Destroy the current logic writer
- **WHEN** a writing computer is destroyed
- **THEN** its still-owned logic outputs clear and no callback can continue using its identity.

### Requirement: Blueprint and clone isolation
Blueprints, entity clones and settings copy SHALL carry applicable source and configuration only, not computer runtime state, event registrations, KV contents, output ownership or active execution. Newly created computers SHALL start stopped, databases empty and logic outputs zero.

#### Scenario: Blueprint a functioning controller
- **WHEN** its blueprint is built elsewhere
- **THEN** code and selected settings are available for inspection but the new computer does not configure the factory until explicitly run.

### Requirement: Save and migration integrity
Ordinary saves SHALL preserve complete live state, data, deadlines and ownership. Schema changes SHALL migrate on permitted synchronized lifecycle stages, never during read-only load. Unsupported/corrupt representations SHALL preserve recoverable user data and refuse unsafe activation.

#### Scenario: Cold save/load
- **WHEN** the packaged mod saves a running factory and another process reloads it
- **THEN** identities, data, current display, timers and active source remain consistent without duplicate startup effects.

### Requirement: Attributable adapted artwork
Devices SHALL use the distinct Factorio-industrial visual family defined by `device-visual-identity`. Original authored artwork is preferred; any retained approved Greg Flavored input SHALL retain its pinned provenance and MIT notices. Runtime sprites SHALL match Factorio perspective, rotations, shadows, status and connectors. Known unresolved provenance SHALL block only the affected asset, not unrelated authored work.

#### Scenario: Asset release audit
- **WHEN** a distributable archive is built
- **THEN** every shipped derived asset has identified inputs, hashes, transformation record and required notices
- **AND** the promotional preview image is not substituted for a verified entity sprite set.

### Requirement: Base-game progression and queryable limits
Unlocks SHALL build on circuit-network progression using base materials. Power/recipe figures SHALL be explicit balance settings documented before release. Resource and geometry limits SHALL be queryable and frozen only after the supported acceptance envelope is measured.

#### Scenario: Unsupported capacity is requested
- **WHEN** a player program exceeds a published device limit
- **THEN** it receives a documented refusal without corrupting accepted state or causing an unbounded simulation workload.

### Requirement: Packaged engine and graphical acceptance
Release acceptance SHALL exercise the exact packaged artifact in base-only and expansion configurations, cold save/load, actual client rendering/input and multiplayer determinism. Headless or mocked checks MUST NOT be represented as graphical or multiplayer acceptance.

#### Scenario: A headless-only validation run
- **WHEN** headless tests pass without a graphical client
- **THEN** the verification record still lists sprite alignment, touch/editor interaction and multiplayer-client behavior as outstanding.

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
