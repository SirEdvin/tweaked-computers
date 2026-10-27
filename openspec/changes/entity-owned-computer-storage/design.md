# Design

## Context

See [proposal.md](proposal.md) for motivation and [the lifecycle delta](specs/device-lifecycle/spec.md) for observable behavior. Discovery used checkout `53f16a4`; the planning branch is based on `136b3a6`, the merge containing it. This document records a design, not executed gameplay verification.

The relevant existing control flow is:

- `scripts/registry.lua` associates a native body/unit number with a logical record in `storage.tweaked_computers.computers`. New computers start with empty saved source/state and stopped status. Removal deletes the live record and invalidates its bindings.
- `scripts/lifecycle-data.lua` already separates settings-only snapshots from source/state snapshots. `computer_snapshot`, `import_computer` and `restore_computer` validate source, revisions, label, formerly active source and explicit state. Restore does not compile source, cancels old work, clears run identity and leaves the computer stopped. Its computer item adapter currently uses these helpers for mining and placement.
- `scripts/lifecycle.lua:132-170` ties computer initialization/minability to item-adapter registration. Simply deleting that adapter would leave new computers unmineable. The build-time fallback and initialization responsibilities must be separated without weakening unknown live-schema protection or touching the KV adapter.
- `scripts/lifecycle.lua:374-429` imports a consumed item's snapshot before blueprint handling, and writes a snapshot to the mining buffer before deleting the record. `scripts/blueprints.lua:103-104` skips blueprint settings when an item was restored. This precedence is confirmed; it is not yet a native reproduction of the report.
- `control.lua` registers blueprint setup, entity settings paste, build/revival, mining and clone events, but no undo/redo integration. `tests/lifecycle_engine.lua` calls `blueprints.prepare` directly after native blueprint creation, so its capture test bypasses the player-facing setup handler.
- Factorio 2.1.23 provides `LuaUndoRedoStack.get_undo_item`, `set_undo_tag`, `set_redo_tag`, and `on_undo_applied`/`on_redo_applied`. Native `LuaEntity.tags` applies to ghosts, not ordinary placed entities. The API describes the available containers but does not establish the event ordering needed for this change.
- `info.json` pins Factorio 2.1.23. Some historical canonical lifecycle text and `AGENTS.md` still mention 2.0.77; use the actual manifest/engine for acceptance, and do not widen this change into a general engine migration.

Primary API reference inspected: `https://lua-api.factorio.com/2.1.23/runtime-api.json`, especially the classes/events above, `on_player_setup_blueprint`, `on_player_mined_entity`, `on_marked_for_deconstruction` and `on_robot_mined_entity`.

## Goals / Non-Goals

**Goals:**

- Reuse the existing authoritative record, snapshot validation, stopped restore and physical lifecycle paths.
- Separate source-only reusable copies from operation-bound undo state, with no item-content dependency.
- Preserve native operation attribution and data isolation across deferred ghost construction, history movement and cold load.
- Prove native keyboard/event delivery as well as serializer correctness.

**Non-Goals:**

- A generic undo framework, permanent recovery archive, world scan, position-keyed resurrection service or new dependency.
- Recovery/migration of old computer items, changes to stack sizes or item IDs, a replacement storage schema for live computers, or changes to KV/monitor item policies.
- Resuming a removed program, reversing its previous factory effects, restoring Console sessions/log history, or rewinding arbitrary editor/settings operations.
- Fixing blueprint paste over an already existing entity as an adjacent feature. Preserve current ordinary entity-settings-copy behavior.
- New numeric limits, resource settings or weakened validation/admission to make a fixture pass.

## Decisions

### 1. Keep the registry; remove computer item transport only

The live registry remains authoritative. Disconnect computer item snapshot writing and restoration in the shared lifecycle, while retaining shared serialization helpers for blueprint and undo consumers. Ordinary computer placement stays on `registry.register` defaults. Treat any old `tc_computer` item tag as irrelevant, including malformed data: do not deserialize it merely to decide to ignore it.

Separate computer initialization/minability from the item-payload adapter so removal of that adapter cannot trigger `awaiting-data-bearing-snapshots`. Preserve explicit handling of unsupported live schemas and the safeguards needed to capture valid undo data; approval to discard old item data is not permission to reset unknown placed data. Other item adapters retain their current behavior.

Keep the native computer item prototype type, ID and stack size unless an actual engine constraint requires a further decision. An unused `item-with-tags` capability is not an application data store and does not justify a prototype migration or inventory sweep. Newly mined items simply receive no computer payload.

Alternative rejected: only change item/blueprint precedence. That retains a transport model the user explicitly chose to remove and does not add undo.

### 2. Define restoration by operation, not by material item

Use the following source of truth for a newly created computer:

| Operation | Payload | Result |
| --- | --- | --- |
| Ordinary item placement | None; old item tags ignored | Blank, stopped, new identity |
| Clipboard/blueprint/clone | Existing source/settings snapshot | Saved source and label; empty state; stopped |
| Verified native undo restoration | Versioned operation-bound full snapshot | Saved source, label, explicit state and formerly active recovery source; stopped |
| Native settings copy onto an existing computer | Existing settings-only path | Replace source/label, retain destination state, stop old run |

Reuse `restore_computer` for validated undo payloads, preserving the distinction between `rec.active` as recoverable source metadata and `run_id`/status as active execution. Do not restore timers, queued events, subscriptions, output writers, shell graphs or log history. Restoration must not call activation or compiler entry points.

For fresh copies, reuse `tc_settings` and existing blueprint role/wire handling. Verify the real `on_player_setup_blueprint` event object and the resulting clipboard/ghost tags before changing its blueprint resolver. Do not assume that `event.record or event.stack` is wrong solely because a copy failed. Capture time, saved-versus-active source and material precedence are independent checks.

### 3. Bind undo payloads to native history and the exact restoration target

Use a small host-only computer undo adapter, rather than spreading a second persistence system across UI and runtime services. Register its hooks during control parsing. Compose it with the existing removal/build handlers; never replace existing event owners or invoke imports from `on_load`.

Capture the computer snapshot while its exact live record is available, before removal cleanup deletes it. Associate it with the correct native per-player action using a versioned tag and an operation identity. Native item/action indexes can move as the player acts, so do not retain an index as permanent identity, tag the newest action indiscriminately, or infer the remover from `LuaEntity.last_user`.

For robot deconstruction, use the player-attributed mark/cancel lifecycle to retain the action association, but take the data snapshot only at actual removal. Cancelling before removal must not restore an earlier state or stop a still-live computer. Script or combat destruction without an attributable undo action must not manufacture player history.

At undo/redo application, validate the operation payload and match the exact engine-created body or ghost, including surface, force, prototype/quality and operation association. Use geometry only to locate candidates within the verified action, never as independent authority to overwrite an occupant. A compatible existing replacement is not automatically the restoration target.

The implementation's first native fixture must establish when history entries become writable and whether undo creates the ghost/body before or after the callbacks. If capture and writable history are separated, retain only the pending association/snapshot needed for that operation in synchronized save-backed state, retire it after handoff/cancellation, and use existing admission. Do not substitute unsaved module-local state, an unbounded historical registry, or repeated whole-world/per-player scans. If the pinned engine cannot support the contract through these hooks, stop and report the specific failed native gate rather than silently weakening undo or inventing a fallback architecture.

Alternative rejected: a global map keyed by coordinates. It can attach stale contents to an unrelated new computer, crosses player/surface boundaries and outlives native undo history.

### 4. Carry deferred restoration in the ghost without turning it into a reusable state copy

Prefer native undo/redo action tags for history retention. When native undo produces a ghost, attach the validated operation-bound snapshot to that exact ghost so later robot/player construction can restore it after a cold load. Use a distinct undo payload from `tc_settings`, and preserve the normal blueprint source/settings representation for inspection and copies.

Before applying an undo-only payload at build/revival, check its association with the genuine restoration target. On failure, retain the recoverable payload in its valid native history/ghost, preserve item conservation, and report an actionable refusal rather than publishing an apparently successful blank replacement.

Blueprint capture must explicitly sanitize computer restoration ghosts: project only saved source/label into source/settings tags and remove full state plus undo authority. The current `blueprints.prepare` passthrough for unregistered entities must not carry a new private undo tag into reusable blueprints. Validation of tag shape alone does not establish that a ghost is the original restoration target.

Undo/redo movement must preserve or transfer the payload to the corresponding opposite-stack action as the native ordering requires. History expiry, cancelled ghosts and invalidated surface/force scopes must retire any auxiliary association. Once restoration is published, duplicate build notifications must take the existing already-registered fast path and leave later edits untouched.

### 5. Preserve existing validation, capacity and authority boundaries

Reuse the existing plain-data computer snapshot validators and content policies instead of serializing the whole live registry record. Native history tags and ghost tags remain input boundaries; reject unsupported versions, executable values and malformed state. Keep source text inert.

A full accepted snapshot must fit the existing transport envelope with its undo metadata. Measure this in the accepted-capacity regression; do not choose a new numeric allowance or increase current limits in the implementation. A refusal must preserve the original snapshot rather than truncate or silently clear it. The explicitly ignored old item payload is a separate, approved discard case, not an exception for live records or undo snapshots.

Keep per-player history attribution separate from the existing same-force world authority. Test interleaved players, old handles, changed force and deleted/recreated surfaces. No unsynchronized wall-clock state or guest callbacks participate in restoration.

### 6. Align contracts and acceptance with the actual workflow

The delta renames the old blanket mining-preservation requirement and updates its complete scenarios, while retaining non-computer obligations. Update `openspec/specs/device-lifecycle/lua-api.md` as the lifecycle companion during implementation so its matrix does not continue promising computer item persistence; this adds no guest method or new peripheral API. Canonical `spec.md` synchronization remains the later archive workflow's responsibility.

Update `docs/player/lifecycle.md`, `docs/player/editor.md`, `docs/player/troubleshooting.md`, relevant getting-started text and any matching in-game help/localization. State plainly that normal pickup/replacement loses computer contents and old computer-item payloads are ignored. Do not imply loss of placed records, private drafts or KV/monitor contents.

Retain existing KV TTL, monitor settings, role wires, stale-handle and cleanup regressions. Replace only computer-item preservation assertions with the approved plain-item/undo assertions; do not delete whole lifecycle tests. Native client coverage must select and paste actual computers and press Ctrl+Z/Ctrl+Y. A direct call to `blueprints.prepare`, injected `on_setup` table or synthetic undo handler is only a lower-level test.

## Risks / Trade-offs

- Intentional loss on ordinary mining/replacement and old item use -> Document the approved break prominently; never extend it to placed data or other device families.
- Native event ordering is not proven by API presence -> Establish it first in the exact engine with real input, and retain the baseline trace and any failure separately from final acceptance.
- Removing the computer adapter accidentally disables mining -> Cover the initialization fallback and body minability explicitly.
- Undo snapshots leak into reusable blueprints -> Separate payloads, sanitize ghost capture, and verify copied-ghost state is empty.
- Wrong action/target receives contents -> Match native action identity and exact target scope; include interleaved/multi-entity history and occupied-target cases.
- Accepted snapshots exceed transport capacity or accumulate outside native history -> Reuse admission, check maximum accepted contents, and release only operation-owned auxiliary state on native retirement.
- Undo is mistaken for resuming the old process -> Assert absence of run/timers/queues/Console/output ownership and zero startup effects before explicit Run.
- Headless helper tests miss the reported gesture -> Keep native-client keyboard acceptance separate from structural and cold-save tests.

## Migration Plan

1. Preserve existing placed records and drafts on upgrade; do not reset the registry or source/state schemas merely to remove item transport.
2. Stop writing and reading computer-item payloads. Leave existing inventory items alone until used; ignore their old computer data without migration, refund-for-recovery, import or recovery UI. Keep ordinary item validation and other family adapters unchanged.
3. Preserve existing source/settings blueprint format. New undo metadata has its own validated version and is introduced only for qualifying operations after this change; pre-update native history without a computer snapshot cannot retroactively reconstruct removed data.
4. Update the lifecycle companion and player guidance, then verify fresh and upgraded populated saves, old tagged items, copied/restoration ghosts and native history across cold reload in base and Space Age.
5. Rollback uses a complete pre-update save and its matching mod archive. Old item contents discarded by placement and ordinary newly mined computer contents cannot be reconstructed by downgrading the mod alone.

No product decision remains open. Native event ordering and exact observed clipboard failure are specifically assigned implementation verification gates, not completed evidence or permission to change the agreed behavior.
