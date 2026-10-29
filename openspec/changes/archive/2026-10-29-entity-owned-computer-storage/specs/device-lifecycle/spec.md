# Spec Delta

## RENAMED Requirements

- FROM: `### Requirement: Mining preserves user data`
- TO: `### Requirement: Device-specific mining data policy`

## MODIFIED Requirements

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

### Requirement: Blueprint and item continuity across shell changes
Existing blueprint, ghost and clone paths SHALL remain supported across a physical-shell change. Internal power helpers MUST NOT add user-visible costs or extra drops. New placed computers SHALL remain stopped and blueprint copies MUST NOT acquire application state or KV contents. Existing non-computer data-bearing items SHALL retain their approved restoration behavior; legacy computer-item payloads SHALL follow the explicit discard policy.

#### Scenario: Use an older blueprint after upgrade
- **WHEN** a player builds a valid blueprint captured before the redesign
- **THEN** the intended devices, captured saved source/settings and role-specific wires are restored without requiring hidden helper items or duplicating application data.

#### Scenario: Replace a mined data-bearing device
- **WHEN** a computer or database item mined before the redesign is placed afterward
- **THEN** an ordinarily placed computer starts blank and stopped with a new identity despite any old item payload
- **AND** the database's approved contents and deadlines are restored under its existing item contract.

## ADDED Requirements

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
