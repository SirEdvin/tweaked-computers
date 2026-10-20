# Spec Delta

## MODIFIED Requirements

### Requirement: Pinned engine and optional expansion
The mod SHALL target Factorio 2.0.77 and operate with base alone or with Space Age enabled. Expansion materials/technology MUST NOT be required by its base recipes. Ordinary radar modems SHALL work without Space Age; the advanced radar entity, item, recipe and technology SHALL exist only with Space Age enabled. Signal and device quality identities SHALL remain correct in both configurations.

#### Scenario: Base-only installation
- **WHEN** the packaged mod is loaded with base and no expansion
- **THEN** prototypes load, devices can be unlocked/crafted and all applicable APIs work without missing expansion references
- **AND** ordinary radar communication works while no advanced-radar entity, item, recipe or research entry exists.

#### Scenario: Expansion installation
- **WHEN** the packaged mod is loaded with Space Age
- **THEN** both radar tiers are available through their intended progression, with no dependency on a planet-specific science pack.

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

## ADDED Requirements

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
