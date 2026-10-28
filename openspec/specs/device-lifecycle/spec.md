# device-lifecycle Specification

## Purpose

Make programmable devices behave as coherent Factorio entities with correct placement, wiring, electricity, save persistence, recoverable mined data and attributable artwork.

## Requirements

### Requirement: Pinned engine and optional expansion
The mod SHALL target Factorio 2.1.23 and operate with base alone or with Space Age enabled. Expansion materials/technology MUST NOT be required by its base recipes. Ordinary radar modems SHALL work without Space Age; the advanced radar entity, item, recipe and technology SHALL exist only with Space Age enabled. Signal and device quality identities SHALL remain correct in both configurations.

#### Scenario: Base-only installation
- **WHEN** the packaged mod is loaded with base and no expansion
- **THEN** prototypes load, devices can be unlocked/crafted and all applicable APIs work without missing expansion references
- **AND** ordinary radar communication works while no advanced-radar entity, item, recipe or research entry exists.

#### Scenario: Expansion installation
- **WHEN** the packaged mod is loaded with Space Age
- **THEN** both radar tiers are available through their intended progression, with no dependency on a planet-specific science pack.

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
The six Service Rack devices SHALL retain the Factorio-industrial visual family defined by `device-visual-identity`. Radar modems SHALL use its native-radar exception rather than replacing vanilla artwork. Original authored assets and native Factorio asset references are preferred; retained approved Greg Flavored inputs SHALL retain pinned provenance and MIT notices. Runtime sprites SHALL match perspective, geometry and connectors. Unresolved provenance SHALL block only affected assets.

#### Scenario: Asset release audit
- **WHEN** a distributable archive is built
- **THEN** every shipped derived asset has identified inputs, hashes, transformation record and required notices
- **AND** the promotional preview image is not substituted for a verified entity sprite set.

#### Scenario: Native radar asset reuse
- **WHEN** the advanced radar reuses installed Factorio sprites, icons, shadows or sounds
- **THEN** the mod references their native asset paths and documents the prototype transformations without packaging Factorio distributions or extracted game assets.

### Requirement: Base-game progression and queryable limits
Mod-built base devices SHALL build on circuit-network progression using base materials; ordinary radar modems SHALL retain vanilla radar progression without a new unlock. The optional advanced radar SHALL use its specified six-pack research. Power/recipe figures SHALL be explicit balance settings documented before release. Resource and geometry limits SHALL be queryable and frozen only after the supported acceptance envelope is measured.

#### Scenario: Unsupported capacity is requested
- **WHEN** a player program exceeds a published device limit
- **THEN** it receives a documented refusal without corrupting accepted state or causing an unbounded simulation workload.

#### Scenario: Ordinary radar already craftable
- **WHEN** a force can already craft vanilla radar and has access to computers
- **THEN** it can use a locally wired radar as a modem without researching an additional ordinary-modem technology.

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

### Requirement: Non-invasive native radar lifecycle
Adopting a supported native radar SHALL NOT replace its body, add power/socket helpers, rewrite native power/scanning settings, suppress native interaction, or alter its drops. Placement, removal, clone, revival and scope changes SHALL reconcile modem identity without applying composite-shell conversion. Integration failure SHALL preserve the native entity and unrelated wires.

#### Scenario: Native build and mine
- **WHEN** a player or robot builds and mines an ordinary radar
- **THEN** modem registration and cleanup occur without extra items, helper entities, duplicate drops or modifications to vanilla scanning/circuit behavior.

#### Scenario: Registration capacity is full
- **WHEN** a placed or existing radar cannot be registered within the declared integration capacity
- **THEN** it remains an intact native radar and modem unavailability is reported explicitly, rather than destroying/refunding it or publishing a functioning partial integration.

### Requirement: Existing-radar adoption
Installation or upgrade SHALL adopt eligible pre-existing radars through deterministic bounded synchronized work, never through state mutation on load. Newly built radars SHALL use the same identity rules. A connected but not yet adopted eligible radar SHALL produce an explicit pending/capacity diagnostic rather than a falsely complete empty inventory. Retried adoption SHALL NOT allocate duplicate identities.

#### Scenario: Install into an existing factory
- **WHEN** the mod is added to a save with vanilla radars and circuit wires on several surfaces
- **THEN** those radars become modem-capable without rebuilding them, their original entities and wires remain unchanged, and other accepted devices/data remain intact.

#### Scenario: Cold load during adoption
- **WHEN** a save is taken while the bounded adoption pass is incomplete and is loaded in a new process
- **THEN** synchronized adoption resumes deterministically without repeating registration or executing guest startup during load.

### Requirement: Advanced radar research and construction
With Space Age enabled, `tc-interplanetary-radar` SHALL have a disabled-by-default recipe unlocked by a dedicated technology using exactly automation, logistic, chemical, production, utility and space science packs. Military and planet-specific science SHALL NOT be required. Prerequisites SHALL make all six packs reachable. Construction SHALL be supported on planets and space platforms subject to ordinary native placement constraints.

#### Scenario: Research ingredient inspection
- **WHEN** a player inspects advanced-radar research
- **THEN** the ingredient set contains exactly the six specified packs and its unlock effect grants the advanced-radar recipe.

#### Scenario: Existing researched force
- **WHEN** a save containing researched advanced-radar technology undergoes configuration reconciliation
- **THEN** its recipe remains unlocked without granting research to forces that have not completed it.

#### Scenario: Planet and platform placement
- **WHEN** a player has the researched item and a sufficiently large valid powered site on a planet or platform
- **THEN** the advanced radar can be placed and wired without a planet-only or stationary-platform requirement.
