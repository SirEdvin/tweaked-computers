# device-lifecycle Specification

## Purpose

Make programmable devices behave as coherent Factorio entities with correct placement, wiring, electricity, save persistence, recoverable mined data and attributable artwork.

## Requirements

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

### Requirement: Coherent composite lifecycle
A composite device SHALL place, rotate, mine, destroy, clone and revive as one logical item. Owned helper entities MUST NOT yield duplicate drops, survive as usable orphans, steal another device's identity or destroy a replacement occupying an old position. Selection, opening and deconstruction SHALL identify the logical device, with auxiliary sockets confined to their explicit role rather than presenting a generic NETWORK tile.

#### Scenario: Partial placement failure
- **WHEN** a required component cannot be created
- **THEN** placement fails or rolls back without consuming an extra item, leaving a functioning partial device or deleting unrelated entities.

#### Scenario: Robot removal
- **WHEN** a robot mines a composite device
- **THEN** all owned parts are removed and exactly one logical item is produced
- **AND** computer items contain no computer source, state or label snapshot, while other device families retain their existing approved item-data policy.

#### Scenario: Deconstruct a device through its footprint
- **WHEN** the player marks a device for deconstruction
- **THEN** the logical device receives the order, its marker is visible and internal parts cannot remain as independently usable devices after removal.

### Requirement: Electricity and passive wire continuity
Devices SHALL require electrical power for active services. Power loss SHALL pause computers, blank monitors without erasing buffers, refuse active KV/configurator services and clear logic output. Stored data and expiry deadlines SHALL remain durable; passive wire/discovery topology SHALL not depend on power.

#### Scenario: Powered computer reaches an unpowered database
- **WHEN** discovery finds a physically connected database without power
- **THEN** its identity and unpowered status remain inspectable but data operations report an explicit unpowered error.

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

### Requirement: Destruction and surface deletion
Destruction SHALL remove the destroyed device's data, handles, owned render objects and pending work. Surface deletion and force changes SHALL reconcile device registries and authority without transferring data to unrelated entities.

#### Scenario: Destroy the current logic writer
- **WHEN** a writing computer is destroyed
- **THEN** its still-owned logic outputs clear and no callback can continue using its identity.

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
Existing blueprint, ghost and clone paths SHALL remain supported across a physical-shell change. Internal power helpers MUST NOT add user-visible costs or extra drops. New placed computers SHALL remain stopped and blueprint copies MUST NOT acquire application state or KV contents. Existing non-computer data-bearing items SHALL retain their approved restoration behavior; legacy computer-item payloads SHALL follow the explicit discard policy.

#### Scenario: Use an older blueprint after upgrade
- **WHEN** a player builds a valid blueprint captured before the redesign
- **THEN** the intended devices, captured saved source/settings and role-specific wires are restored without requiring hidden helper items or duplicating application data.

#### Scenario: Replace a mined data-bearing device
- **WHEN** a computer or database item mined before the redesign is placed afterward
- **THEN** an ordinarily placed computer starts blank and stopped with a new identity despite any old item payload
- **AND** the database's approved contents and deadlines are restored under its existing item contract.

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

### Requirement: Dashboard physical identity and progression
The dashboard SHALL be a recognizable base-material control panel with a single data-bearing item and recipe unlocked through existing computer progression. Its icon, footprint, network contacts and power state SHALL agree with its native window identity. Existing device artwork and gameplay SHALL remain unchanged; added art SHALL retain reproducible provenance.

#### Scenario: Upgrade an already researched force
- **WHEN** the feature is installed in a force that already researched circuit computers
- **THEN** its dashboard recipe is available without rebuilding existing devices or researching an expansion technology.

#### Scenario: Inspect physical feedback
- **WHEN** a player selects, wires, rotates or marks the dashboard for deconstruction
- **THEN** its body, connector and native feedback remain legible and no internal helper appears as a separately buildable peripheral.

### Requirement: Entity-owned computer data
A placed computer's saved source, label and explicit application state SHALL belong to that physical computer's save-backed logical record. Ordinary save/load and an update introducing this policy MUST NOT reset placed-computer data or retarget player drafts. Physical replacement SHALL allocate a new identity; only explicit blueprint or qualifying undo snapshots SHALL supply its contents.

#### Scenario: Update a populated world
- **WHEN** a world with placed computers, active programs, stored state and retained player drafts is upgraded to this policy
- **THEN** those placed records, running-program behavior and drafts remain intact without blanket resets or startup replay
- **AND** future computer item transport follows the new plain-item policy.

#### Scenario: Stale handle or draft after restoration
- **WHEN** a computer is removed and a replacement or undo-restored computer appears at the same coordinates
- **THEN** it has a distinct logical identity, and stale wrappers, editor sessions and drafts cannot silently address the new computer.

### Requirement: Legacy computer-item payload discard
Previously stored computer-item contents SHALL be ignored on placement, without legacy import, migration or item-data recovery. This includes valid, malformed and unsupported old computer payloads. This deliberate compatibility break MUST NOT discard placed-computer records, player drafts or other device families' item contents, and SHALL be stated in upgrade guidance.

#### Scenario: Place an old programmed computer item
- **WHEN** an old item containing saved source, state or a computer label is placed normally
- **THEN** the new computer is blank and stopped, no old item code executes, and subsequently mining it writes no computer payload.

#### Scenario: Old item used for a copy or undo
- **WHEN** a blueprint or qualifying undo placement consumes an old tagged computer item
- **THEN** the operation's own snapshot determines the restored contents, and the item's old computer payload neither overrides them nor blocks placement.

#### Scenario: Malformed legacy payload
- **WHEN** the computer item contains a malformed or unsupported old computer payload
- **THEN** that payload is ignored rather than imported, executed or used to fault the newly placed computer
- **AND** normal construction validation and other device families' malformed-item protections remain intact.

### Requirement: Stopped computer restoration through undo
Undoing an undoable computer removal SHALL restore the saved source, label and explicit application state from immediately before removal. A different formerly active source SHALL remain available as recovery text. The restored computer SHALL have a new identity and remain stopped, with no active run, timers, subscriptions, queued callbacks, Console session or old output ownership. Unsaved drafts SHALL stay separate.

#### Scenario: Remove a running computer and undo
- **WHEN** a player removes a computer with saved code, a label, explicit state, timers and pending callbacks, then uses Ctrl+Z and completes any required construction
- **THEN** saved code, label and explicit state match the pre-removal snapshot exactly
- **AND** no startup, timer, callback or previous output ownership resumes until the player explicitly runs the new computer.

#### Scenario: Saved and formerly active source differ
- **WHEN** the removed computer was running a different source from its latest saved document
- **THEN** undo restores the saved document as saved source and retains the formerly active document for reviewed recovery only
- **AND** neither source nor any unsaved editor draft executes automatically.

#### Scenario: Undo deconstruction before and after removal
- **WHEN** a player undoes a deconstruction order before the computer is removed
- **THEN** cancelling the order does not replace the live computer or reset its current data/run
- **AND** after actual robot removal, undo restoration uses the contents at removal time, not an earlier snapshot taken when the order was marked.

### Requirement: Undo history and ghost continuity
Computer undo snapshots SHALL follow the corresponding native per-player undo/redo action, and survive save/load while that action remains available. A restoration ghost SHALL retain its snapshot until construction or cancellation. Repeated undo/redo SHALL preserve the applicable snapshot without duplicating items, runtime work or application effects. Native history expiry SHALL not leave an independent permanent recovery archive.

#### Scenario: Cold load before undo and before ghost construction
- **WHEN** the game is saved after removal but before Ctrl+Z, or after Ctrl+Z has produced a restoration ghost but before construction
- **THEN** cold reload preserves the applicable snapshot and subsequent restoration returns the exact saved code/state in stopped form
- **AND** loading itself performs no restoration or guest execution.

#### Scenario: Multiple removals and redo
- **WHEN** one undoable operation removes several computers with different contents and the player cycles undo, redo and undo
- **THEN** each matching computer receives its own applicable snapshot without swapping data or reviving callbacks
- **AND** native item consumption, refunds, helper cleanup and unaffected entities remain correct.

#### Scenario: Copy a restoration ghost
- **WHEN** a restoration ghost is copied into a reusable blueprint or clipboard selection
- **THEN** the resulting copy includes only its saved source/label and normal configuration, not undo-only application state or history authority
- **AND** building that copy starts a stopped computer with empty application state.

#### Scenario: Native history is no longer available
- **WHEN** native undo/redo history expires or is discarded, or a restoration ghost is cancelled
- **THEN** no independent permanent computer recovery entry remains solely for that discarded operation
- **AND** a later ordinary placement does not recover the old contents by position.

### Requirement: Safe undo attribution and restoration
Undo restoration SHALL validate snapshot format and exact action/target association before publishing computer contents. It MUST NOT write into an unrelated replacement, another player's mismatched operation, an unauthorized force or a deleted/recreated surface. Refused restoration SHALL report failure and preserve recoverable snapshot data without activating source, silently truncating contents or destroying unrelated entities.

#### Scenario: Occupied or stale target
- **WHEN** a restoration target is occupied by an unrelated entity, belongs to a changed unauthorized scope, or no longer refers to the original surface
- **THEN** restoration does not overwrite or remove the unrelated target, and no old source executes
- **AND** recoverable undo data is retained while its native history/ghost remains valid.

#### Scenario: Malformed or over-capacity restoration
- **WHEN** an undo snapshot is unsupported, malformed, or cannot currently be admitted under the existing snapshot/state policies
- **THEN** restoration fails explicitly without partial source/state publication, extra item loss or automatic execution
- **AND** the original snapshot remains available within its valid history/ghost for recovery rather than being replaced with empty data.

#### Scenario: Accepted-content boundary and duplicate delivery
- **WHEN** a computer at its accepted source/state capacity is removed and restored, or the same build event is delivered again
- **THEN** an admissible snapshot round-trips without truncation and is applied only once to the intended new identity
- **AND** duplicate delivery does not overwrite later edits, create duplicate helpers or renew runtime work.

### Requirement: Consolidated live monitor observation
Recurring monitor physical observation SHALL be consolidated into one minimal pass per actual simulation tick. Unchanged observations SHALL NOT trigger duplicate full physical validation, grouping reconstruction or presentation work. Existing power, component ownership and physical-change behavior SHALL remain intact; this optimization SHALL NOT introduce a slower idle polling interval or suppress maintenance merely because programs are stopped.

#### Scenario: Settled monitor array
- **WHEN** a powered array remains unchanged and has no pending physical repair
- **THEN** the normal tick observes the live state needed to detect power and physical invalidation once through the consolidated path
- **AND** generic lifecycle, grouping and presentation phases do not independently repeat full all-member validation of that unchanged array; actual service, interaction, selected-path and publication proofs remain separately permitted and accountable.

#### Scenario: Outage and recovery without peripheral calls
- **WHEN** a tile in a settled logical display loses power and later regains it without any drawing calls
- **THEN** the existing power-loss safety ordering and admitted hide/restore behavior apply without an added polling delay
- **AND** all-member power requirements, retained buffers and passive wire continuity remain unchanged.

#### Scenario: Silent physical change
- **WHEN** another script moves, rotates, changes the force or surface of a monitor, or invalidates its body or owned helper without a usable notification
- **THEN** live observation detects the changed physical state through the normal lifecycle path and schedules the required invalidation or reconciliation
- **AND** stale geometry, ownership or power cannot remain trusted simply because the presentation work list is empty.

#### Scenario: Unchanged neighboring device families
- **WHEN** monitor observation is removed from duplicate generic maintenance paths
- **THEN** computers, logic, databases, configurators, speakers and radar tracking retain their existing power, cleanup, discovery and safety behavior
- **AND** monitor tile identities and real circuit endpoints remain registered for passive discovery rather than being treated as dormant radars.

### Requirement: Fresh operation-boundary monitor authority
Monitor operations SHALL retain their operation-specific identity, ownership, scope, geometry, power and circuit checks, including existing query-only power exceptions. A prior observation or matching simulation tick SHALL NOT authorize a later operation after native state changes. Positive proof reuse SHALL be limited to a non-mutating operation scope; deferred work SHALL retain identities and revalidate them rather than retain reusable authority.

#### Scenario: Native changes within the same event
- **WHEN** an earlier check succeeds and native code then moves or rotates a tile, changes its force, removes an owned helper or removes power before a later check in the same event
- **THEN** the later guarded active operation or publication refuses the now-invalid state even though the simulation tick is unchanged
- **AND** restoring the state permits a fresh proof without requiring a tick advance.

#### Scenario: Retired identity still has queued work
- **WHEN** a monitor or selecting computer is removed, replaced or regrouped while presentation work is pending
- **THEN** that work cannot publish through the retired identity or affect an unrelated replacement
- **AND** owned cleanup completes under existing budgets while accepted surviving models remain recoverable.

#### Scenario: Idle Console selection loses its path
- **WHEN** a live Console-owned monitor selection has no ready frame and its selected wire path is definitively revoked while the saved program is stopped
- **THEN** the existing bounded authority maintenance detects and releases the selection with its existing diagnostic semantics, without waiting for a new drawing call
- **AND** a temporarily incomplete proof blocks rather than falsely detaches, and no alternative wire color is silently substituted.

### Requirement: Reliable monitor invalidation delivery
Accepted physical, settings, power and ownership transitions SHALL notify the affected monitor work before stale state can be published. Repeated notifications SHALL remain bounded by retained devices and work rather than event history. Budget refusal, further invalidation and save/reload SHALL NOT lose the need for reconciliation, visibility changes or cleanup.

#### Scenario: Supported lifecycle entry points
- **WHEN** placement, revival, clone, rotation, actual removal, settings paste, force merge or surface removal affects a monitor
- **THEN** the existing lifecycle handlers deliver the corresponding monitor invalidation without requiring a guest call or a periodic full signature sweep
- **AND** clone/item isolation, settings inheritance, helper ownership and removal guarantees remain unchanged.

#### Scenario: Deferred work followed by another change
- **WHEN** a monitor transition has scheduled reconciliation or cleanup but admission defers it and another relevant transition occurs
- **THEN** the newer invalidation remains represented until valid current state commits or owned cleanup completes
- **AND** repeated scheduling neither renews credits nor retains one work record per repeated event.

#### Scenario: Initialization and unsupported retained state
- **WHEN** upgrade introduces monitor observation metadata or retained metadata is unsupported
- **THEN** permitted synchronized initialization preserves existing state and valid unfinished work, while unsupported representations remain recoverable and cannot authorize unsafe operation
- **AND** ordinary load performs no world mutation, queue reconstruction, guest execution or native object creation.
