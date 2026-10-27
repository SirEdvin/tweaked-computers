# Proposal

## Why

Players report that Ctrl+C/Ctrl+V onto empty ground and deletion followed by Ctrl+Z produce computers without their saved programs. The current lifecycle couples computer contents to mined items, lets those contents override blueprint source, and has no custom undo capture/restoration; an entity-owned model makes copying and undo independent of the construction item.

## What Changes

- **BREAKING:** Computer items become plain hardware. Mining no longer writes saved/active source, application state or labels into them; ordinary placement creates a blank, stopped computer with a new identity.
- **BREAKING:** Ignore pre-existing `tc_computer` item payloads, including malformed or unsupported payloads. Their data may be lost as explicitly approved; there is no migration, import or recovery path for old computer-item contents. This does not authorize deleting placed-computer records or player drafts.
- Keep placed-computer data in the existing save-backed, entity-associated registry. Do not replace the registry with native entity tags or introduce another general storage service.
- Make actual clipboard/blueprint placement carry the captured saved source and label, regardless of fresh, previously mined or legacy-tagged construction items. New copies start stopped with empty application state and no runtime work.
- Add native undo/redo integration for undoable computer removal. Restore saved source, label and explicit application state into a new stopped identity; preserve a different formerly active source only as recovery text, never as resumed execution. Timers, callbacks, queues, Console sessions and output ownership do not return.
- Preserve native undo action identity, ghost/revival handoff, cold-save behavior, authority checks and player-draft isolation. Keep KV contents/deadlines, monitor item settings, other device lifecycles, item stack sizes and public Lua methods unchanged.
- Update lifecycle documentation and verification to cover the actual native Ctrl+C/Ctrl+V and Ctrl+Z workflows, not just direct calls to snapshot helpers.

## Capabilities

### New Capabilities

None. Computer storage and undo belong to the existing physical-device lifecycle capability.

### Modified Capabilities

- `device-lifecycle`: Replace computer item transport with plain-item semantics; specify source-only clipboard/blueprint copies, stopped-state undo restoration, explicit legacy-item data discard and unchanged non-computer item behavior. Reconcile the existing lifecycle Lua companion with this policy.

## Impact

- Production implementation areas: `control.lua`, `scripts/lifecycle.lua`, `scripts/lifecycle-data.lua`, `scripts/blueprints.lua`, and the existing registry/runtime cleanup boundaries; a focused undo adapter may be warranted after native event ordering is verified.
- Regression areas: `tests/lifecycle_engine.lua`, `tests/rd1_upgrade_engine.lua`, related editor/item fixtures, and the packaged production-context/native-client harness.
- Documentation: the lifecycle companion, player lifecycle/editor/troubleshooting guidance and any in-game lifecycle wording.
- Target the manifest-pinned Factorio 2.1.23, base and Space Age. No new dependency, guest API, resource setting, numeric capacity policy or item stack-size change is proposed.
- Evidence boundary: item-over-blueprint precedence and absent undo integration are source observations. The user's exact native clipboard failure has not been reproduced, so removing item precedence alone is not claimed to fix it. Native reproduction and regression coverage are implementation acceptance gates.
