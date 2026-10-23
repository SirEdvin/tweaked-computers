# Monitor resource-policy integration checkpoint

This is an **incomplete integration checkpoint**, not completion of change tasks 9.1–9.4 or a release claim. No default budget or acceptance deadline is raised.

## Implemented in the monitor lane

- New grouping uses effective `monitor_width_tiles` / `monitor_height_tiles` in local display axes, including east/west rotation. These settings are not part of the physical signature: lowering them alone does not repartition accepted displays. Inspection validates the supported six-tile domain, not the lowered admission setting. In-flight old partition jobs retain their original six-tile policy.
- Model scale validation accepts positive finite scales and safe integer dimensions, rather than half-steps. Existing storage envelopes remain deliberately enforced until actual host lifetime ownership exists. This is not yet permission to use new scales in player saves: item import/paste/export validation and extreme native sprite geometry need integration below.
- Internal `rendering.select(c,tick,spend,members,principal,group_key)` and `rendering.status(c,spend,principal,group_key)` support a nil default and nonempty string named keys. The existing default selection stays at `owner.monitor_sync`; named selections use `owner.monitor_sync_groups[key]`. More than four members and eight supplied references are supported; duplicate paths canonicalize to red. Overlap with a different key is `E_BUSY`, even within one principal. Empty input clears only the given key. Replacement validates/prepays before removing prior selection. Revocation removes affected selections; principal cleanup/Stop removes all its selections without rolling back model cells.
- `rendering.release(c,reason,principal)` remains all-groups cleanup. `rendering.revoke(c,name,wire,principal)` is path-scoped cleanup. Program and shell principals remain separate.
- Ready jobs now honor unfinished invocation holds as well as seal-time holds. A previously prepared image cannot replace the old front during a later unfinished touching invocation.
- Whole-commit work uses effective `render_commit_work`, is accumulated across groups per actual tick, and never resets on a setting change or same-tick re-entry. Intrinsically oversized commits retain old visible fronts and ready hidden jobs with `E_CAPACITY`, `resource`, `setting`, `requested`, `limit`, and `recoverable` guidance. Restoring the setting permits the same job to finish without producer replay.

## Required cross-lane integration (not implemented here)

### Public peripheral API

`services/peripheral.lua` still enforces the legacy arities. Its owner must wire:

- `setMonitorSyncGroup(members [, group_key])`: exactly one or two arguments; perform `current()`, validate the optional nil/nonempty-string key, prepare the zero-result tuple **before** selection effects, then call `monitor_sync.set(computer,tick,spend,members,execution,group_key)`.
- `getMonitorSyncGroup([group_key])`: zero or one argument; perform `current()`, pass `monitor_sync.get(computer,spend,execution,group_key)`, preserve the single defensive status result.
- Preserve dot-call errors, result preparation, authority and principal binding. No fixed group/reference/member count check should replace the removed ones.

The dedicated fixture exercises the real internal provider and actual live program principal, not the missing public optional-argument bridge. Legacy public calls remain unchanged.

### Model settings and native geometry

`lifecycle-data.lua:import_monitor` still accepts only half-steps 0.5..5. Its owner must use the same positive-finite/native geometry validation for item snapshot, restore and paste, and preflight the complete replacement before changing `rec.monitor_settings` or any existing model/palette. Arbitrarily large finite sprite scales also need pinned-engine representability validation. Until these are integrated, new scales are **not release-ready**: they can fail mining/settings export, and extreme finite values are not proven safe for native rendering.

### Shared host lifetime ownership

No host account accessor or monitor-owned lifetime adapter exists in this worktree. Do not remove the remaining cell/tile/write/frame gates until the real shared account is connected. No independent monitor account, silent no-op adapter, or fictional zero usage was added.

Required foundation interface: an authoritative persisted `host_account(root)` returning the same `runtime.memory` account used by all host services, with effective `host_memory_bytes`, host-specific refusal metadata and grandfathered shrink/release semantics. Existing `memory.owner`, `reserve`, `acquire_all`, `release`, and incremental `close` can then implement monitor ownership; there must also be an agreed accounted native-object token/weight (the ledger currently only accepts plain tables/strings).

Actual ownership edges to integrate, not cell-count estimates presented as heap bytes:

1. Group model root, palette root/triples, cells root/immutable cell triples, damage map, holds and metadata. COW roots and shared triples must be distinct ledger records: snapshot sharing is not a second copy of every cell.
2. Pending snapshot roots/contexts/damage vectors and per-principal selections/path arrays/key strings. Atomic replacement must admit all new ownership links and peak scratch before releasing old selection or pending roots.
3. Staging frame/cell maps, reused/index maps, cursor/panel and each newly created native object. Native creation must be preceded by admission. Borrowed background/glyph/panel/cursor objects acquire a link, not another native charge.
4. Front ownership transfers at the prepaid visibility barrier; superseded front ownership transfers to retirement. Cancelled staging releases only its own objects/links. Native charge remains until actual `destroy`, including orphan and partial-cleanup paths.
5. Regrouping keeps old accepted models/fronts and all staged replacements charged simultaneously. Legacy/cold adoption must preserve aliases and incrementally account the existing graph before growth; do not scan another mutable lane's graph through a saved cursor.

Peak admission needs are the **union** of old front/model, COW model growth, one admitted staging vector, one coalesced pending vector, retained retirement/orphans, and current native-operation scratch, plus ledger links/records. A full replacement may retain old and new native images concurrently. Use actual table edges/object inventories and the shared accounting constants; do not preallocate a maximum 6×6 grid for a small display or substitute another fixed cell/frame count. The existing frame counters are diagnostics/scheduling bookkeeping, not an implementation of this account.

### Scheduler and scalable work

The scheduler still caps render-demand reservations at 160000 independently of the new setting. The foundation owner must make demand validation/reservation dynamic without renewing paid credits. The monitor lane still requests the baseline-compatible 160000 demand; raising only `tc-render-commit-work` cannot guarantee progress above that scheduler ceiling. Full tiny-budget fairness also needs durable preparation of whole-vector capture/root-copy/admission work; the current old-implementation atomic preparation loops and fixed cardinality gates remain. Check all waiting/preparing/ready/retiring cold boundaries after integrating this, then rerun both unchanged chart layouts.

## Verification boundaries

`tests.resource_policy_monitor` extends the actual production-context invocation-hold/cold/Stop fixture. `tests.monitor_policy_contract` adds internal-provider named-group, duplicate-path, refusal atomicity, configured-axis/orientation, model-scale validation and settings-decrease contracts. Native logs and archive receipts are outside git; the final lane report identifies exactly which archive was run. No GUI, player-save, graphical FPS or multiplayer acceptance is implied.
