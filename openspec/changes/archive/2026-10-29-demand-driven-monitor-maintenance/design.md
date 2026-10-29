# Design

## Context

See [proposal.md](proposal.md) for motivation and scope. Planning is based on source revision `aa683664a1c2f779e8afcbda472807916382263e`; implementation must recheck the working tree before using that baseline.

Observed paths:

| Area | Current behavior to replace or preserve |
| --- | --- |
| `scripts/monitor-model.lua` | Already retains sparse damage, full-invalidation generations, fixed snapshots and acknowledgement that must not consume later writes. |
| `scripts/services/monitor.lua` | Mutating methods notify presentation after success. `reconcile` nevertheless collects all tiles, builds a complete signature and recomputes every group's availability each tick. Partition initialization is already resumable. |
| `scripts/monitor-presentation.lua` | Already owns lanes, bounded newest-pending vectors, admitted jobs, retirement and fair service. Its tick still enumerates every group/lane, validates availability and attempts sealing. |
| `scripts/lifecycle.lua` | Both `power_losses` and `reconcile` traverse physical records and prove monitor components/power. This duplicates work also performed in grouping and presentation. |
| `scripts/lifecycle-data.lua` | Settings paste can change palette/scale/blink and invalidate a model directly, without passing through monitor peripheral methods. |
| `scripts/services/peripheral.lua` and `scripts/monitor-presentation.lua` | Fresh operation authority and operation-scoped positive proofs already exist. Idle Console selections also validate their retained paths; they have no running-program subscription sweep to substitute for this. |
| `scripts/device-art.lua` and `scripts/rendering.lua` | Monitor status art is checked in a recurring generic walk; the terminal cursor uses a native blink interval, not a required per-tick redraw. |

The user confirmed two decisions before capture: structural no-unnecessary-work gates with timing reports but no numerical timing threshold; preserve current power/physical behavior using one minimal live observation path plus fresh operation checks. No new limits were requested or approved.

The declared engine in `info.json` and current README is Factorio 2.1.23, base alone or optional Space Age. The canonical `device-lifecycle` engine requirement still says 2.0.77. That is pre-existing documentation drift, not an instruction to port this change backward; this delta adds monitor requirements without silently editing that unrelated requirement. Execution and evidence must name the actual 2.1.23 engine. Historical 2.0.77 graphical evidence is not acceptance here.

## Goals / Non-Goals

**Goals:** reuse the existing renderer and budgets; remove redundant work for both stopped and active producers; preserve fresh authority, image coherence and durable progress; make skipped work observable through focused test counters.

**Non-Goals:** a new renderer, command interpreter, event framework, generic scheduler rewrite, native-object cache hierarchy, delayed power semantics, broader device optimization, public queue API, changed capacities, a universal millisecond/FPS guarantee, or release/publication during this planning workflow.

## Decisions

### 1. Queue demand for existing lanes, not guest commands

Keep the shared model synchronous and the current post-dispatch sealing boundary. Extend existing presentation state with a deduplicated, deterministic work index keyed by live logical display or selected-group identity. This is an index into existing ownership and jobs, not a second snapshot/job queue. Bound metadata by admitted displays/selections and compact removed entries; repeated writes/events must not accumulate tombstones or one record per call.

Use an explicit reason to keep a lane eligible: successful mutation/round readiness, model or geometry invalidation, visibility transition, pending admission, preparation, ready publication or cleanup. Keep a lane in fair service while it has unfinished runnable work. Park a round waiting only for participation or a power transition, then wake it from the corresponding change. Capacity/credit deferral retains the request and retries under existing fair actual-tick admission; it must not require another write.

Successful no-op mutations still record participation and preserve sequence semantics. A dirty flag cannot stand in for participation. Getters do not enqueue work. Clear a serviced demand only if the serviced revision/epoch still matches; a write, full invalidation or reentrant lifecycle change occurring after capture must remain represented. Reuse existing damage generations and fixed-snapshot acknowledgement rather than building a competing invalidation scheme.

An optional reverse member-to-selected-lane index is justified only to replace the existing all-lane `owner_of` search on every write; maintain it atomically with the existing selection ownership. It must not become a second source of authority. Use existing deterministic ordering/fair cursors, never process-local table layout or wall-clock timing to select winners.

**Rejected:** queuing the calls themselves (breaks read-after-write/errors); another frame buffer (duplicates existing bounds); a debounce timer (changes frame semantics); skipping only stopped programs (does not fix active monitors).

### 2. Consolidate observation; do not cache authority by tick

Integrate the monitor observation path into existing early lifecycle safety ordering. Read the necessary live body/helper validity, power, position, direction, force/surface and ownership-relevant identity once for normal recurring maintenance. Compare scalar observations with retained state and dispatch only actual changes into existing cleanup/repair/power behavior. Remove monitors from the duplicate full validation branches of generic physical reconciliation and the grouping/presenter sweeps, without unregistering their identities or circuit endpoints.

Do not merely rename the current full connector/availability walk as a cheap observation pass. Avoid repeated native property reads, position-table construction, signature formatting and complete all-member proofs within normal unchanged maintenance. Reuse a locally observed fact only within the proven non-mutating operation that obtained it. Observation is a change detector, never permission for a later guest call or publication.

Preserve fresh boundary validation in the peripheral guard, touch/inspection paths and frame publication. The existing operation-scoped positive proof optimization is retained, not widened to a simulation-tick cache. `tests/monitor_component_contract.lua` explicitly changes position, direction, force and energy between checks in the same event; those refusals remain a hard gate. A deferred transition does not authorize service using an old positive observation.

Known lifecycle events notify changes directly, but the observation path remains necessary for power and silent native mutations. An event-only design is not equivalent to the selected behavior. Keep idle selected-path authority maintenance, especially Console-owned selections, separate from expensive all-screen rendering qualification. Reuse existing witness/revocation machinery; do not invent a mirrored circuit graph or assume stopped programs imply no selection owner.

Monitor status-art refresh should consume actual state/direction changes and necessary invalid-object recovery rather than duplicate native sampling/string construction every tick. Preserve generic status art for other device families and native cursor blinking.

**Rejected:** a long idle polling interval (not approved); tick-keyed physical proof reuse (same-event stale authority); removing idle Console qualification with the render scan (leaks revoked ownership).

### 3. Invalidate grouping instead of rediscovering stability

Keep the existing deterministic partitioner, survivor/settings rules, resumable initializer and atomic group publication. A topology/policy dirty generation replaces the recurring complete tile-signature construction. Collect/compare topology only when dirty or when an admitted job needs current-state validation/progress.

Use a conservative full reconciliation after a genuine topology change initially; the critical optimization is not doing it on stable ticks. Local connected-component repartitioning is not required and would introduce a second topology mechanism. Unaffected group objects/fronts must still survive that reconciliation unchanged. Work against a captured invalidation generation; commit/acknowledge only if it remains current. When further changes arrive, preserve the new demand and prevent publication of obsolete membership. Continue paying for initialization and retries through the existing ledger.

Only relevant geometry/policy changes mark grouping dirty. Ordinary drawing, cursor blink, power changes, native deconstruction marking and status reads do not repartition walls. Power changes affect availability/visibility, not grouping. Removal after deconstruction is a real topology change.

### 4. Make every wakeup source explicit

Use narrow notifications in the modules that already own each transition; avoid a generic event bus or new library.

| Source | Required effect |
| --- | --- |
| Successful terminal mutation | Preserve immediate model mutation and selected-round participation; deduplicate eligible presentation demand. |
| Scale change or settings paste/import | Preserve existing validation/settings rules; invalidate the affected model/staging and arrange presentation/resize work as required. Settings paste does not manufacture guest participation. |
| Build/revive/clone/rotate/actual remove | Mark topology dirty through the existing lifecycle; preserve identity/clone/item isolation and owned cleanup. |
| Silent position/direction/scope/helper changes | Minimal observation marks affected availability/topology invalid and enters existing reconciliation/repair. |
| Power loss/restoration | Enqueue admitted hide/restore and selection blockage/recovery without clearing models or waiting for a writer. |
| Selection/clear/release, stop/fault/run replacement, shell retirement | Maintain membership/work indices, cancel only unpublished owned work, then wake released singleton displays. |
| Definitive selected-path revocation or temporary proof failure | Preserve release versus blocked distinctions, including idle shell selections and exact wire binding. |
| Force merge/surface removal | Reconcile existing registry authority and retire only owned work; never retarget a replacement by coordinates. |
| Job ready, credit/capacity recovery, cancellation or retirement | Continue existing bounded work fairly without another peripheral call. |
| Init/configuration upgrade or missing old bookkeeping | Enroll existing state once in synchronized work; ordinary load does not rebuild queues or objects. |

Producers of notifications must not introduce a new fallible admission step after a successful guest mutation that could lose its wakeup. Keep the needed bounded marker capacity with existing admitted state or reserve required growth before mutation. Repeated scheduling and refused maintenance must not grow retained metadata or reset credits.

### 5. Persist work intent, never reusable permission

Retain work identities, reason/revision markers, membership generation, fair position and progress as validated saveable data alongside existing presentation state. Do not retain closures, iterator objects, cached native authorization or guest functions. Existing native render handles keep their current lifecycle ownership; they are not evidence of current permission.

A valid ordinary cold load resumes the saved pending/preparing/ready/retiring states without a global redraw or source replay. Missing bookkeeping in an older supported save is initialized once on configuration change or the next permitted synchronized lifecycle step. Preserve accepted snapshots, selections and already-paid progress rather than dropping and resealing them. Unknown/corrupt formats fail closed and preserve recoverable data, consistent with existing storage handling.

The early observation path must refresh live facts before relying on saved availability. Same-tick work reservations and spent credits stay frozen across repeated entry/load. All additional metadata must remain within existing ownership/capacity/accounting; do not create a second maintenance allowance.

### 6. Test structural work separately from elapsed CPU

Add the smallest focused native fixture needed to assert work elimination through the production scheduler. Proposed new path: `tests/monitor_demand_engine.lua`, with its supported production-context/cold registration in `control.lua` and `tools/smoke.py`. Extend neighboring suites rather than replace them:

- `tests/monitor_snapshot_contract.lua`, `tests/monitor_budget_contract.lua`, `tests/monitor_optimization_contract.lua`: immutable captures, later-write acknowledgement, no-op participation, component reuse, refusal and unchanged accounting.
- `tests/monitor_component_contract.lua`: fresh same-event native authority, canceled staging and ownership transfer.
- `tests/monitor_state_engine.lua` and its waiting/preparing/ready/retiring wrappers: exact cold work/credits; add settled/pending/budget-refused boundaries to the focused fixture as needed.
- `tests/shell_contract.lua`, `tests/shell_cold.lua` and relevant native shell fixture: idle selection release and live shell/program principal separation.
- `tests/monitor_animation_engine.lua`, `tests/monitor_feedback_engine.lua` and `tests/acceptance_monitor_engine.lua`: unchanged cadence, coherent fronts, native feedback and touch semantics.

Contract counters must distinguish full topology scans, full physical proofs, snapshot capture, frame/cell preparation, visibility writes, native allocation/retirement, observation visits and necessary selected-path checks. Install observers before the modules capture/register the functions being observed. Prove the new assertions fail against the unchanged baseline for the intended redundant work; do not accept a counter that only observes an unused wrapper. Use real scheduler ticks for recurring-work acceptance; keep direct same-event authority probes separately labeled.

Assert zero unnecessary work only after initialization/retirement settles. Verify one independent changing screen does not wake its three unchanged peers. For a synchronized cohort, service the required whole cohort; do not mislabel coherent group work as waste. Assert all tiles and intended producer/power state remain present throughout every window. Preserve teardown, restoration, pending admission, membership invalidation, no-op round and fairness coverage at unchanged caps. Structural counters, not wall-clock readings, form the deterministic performance gate.

Reuse `tools/monitor_performance.py` and `tests/monitor_performance_engine.lua` for matched timing rather than adding an unrelated benchmark framework. Extend their documented workload configuration to cover the zero-monitor control, settled/stopped 144 tiles and one independent updating screen; retain existing sparse/full-blit all-screen modes, per-phase provenance and exact sample checks. Keep its actual production payloads unchanged inside each test archive. Total-timing runs do not contain the fine-grained counter/profiler instrumentation; separately instrument phases for attribution and disclose observer/GC effects.

Freeze both immutable 0.1.16 and a pre-implementation source build. If relevant payloads differ, compare against the pre-change build too so unrelated changes are not credited to this optimization. Baseline and candidate run serially with identical guest source, scene, scale, engine/content mode, budgets and measurement windows. Verify base-only bundled-mod exclusion, including recycler, and optional Space Age explicitly. Require repeated cold windows, exact sample counts, completion markers, no forced cleanup, hashes and mean/median/p95/max. Retain the existing two-tick chart publication gate and both four-walls/mixed layouts; successful cadence is not measured client FPS. Report elapsed regressions honestly without inventing an unapproved millisecond or percentage rejection threshold.

## Risks / Trade-offs

- Lost or prematurely cleared wakeup → generation-aware acknowledgement, burst/during-preparation/refusal/cold tests and an idle-to-first-write regression.
- A parked group never wakes → explicit source matrix, power/selection/backpressure recovery tests and continuous retirement service.
- Stale positive physical proof → separate observation from authorization; retain same-event native rejection and idle Console revocation tests.
- Queue growth or unstable order → deduplicate by admitted identity, clean removal/replacement indices, persist deterministic fair progress and exercise repeated topology/selection churn.
- Preserving native power response leaves nonzero idle work → intentionally retain the minimal pass; report residual CPU instead of promising zero overhead or weakening semantics.
- Structural gates pass but a newly introduced cost dominates → whole-scheduler idle/partial/active comparisons remain required, with regressions explained rather than hidden behind phase counters.
- Existing fixtures mutate models directly and rely on presenter polling → route those fixtures through the real mutation/invalidation boundary or explicitly signal their trusted test mutation; do not retain a production global scan solely for test shortcuts. Preserve their original state, refusal and ownership assertions.
- Settings-paste scale/resize or unsupported-state behavior reveals a pre-existing contract gap → preserve a baseline reproduction and resolve the narrow contract mismatch explicitly; do not silently redefine the API while adding scheduling.
- Missing licensed 2.1.23 client or connected peers → record graphical/multiplayer gates as incomplete; historical engine evidence and a headless pass do not satisfy them.

## Migration Plan

1. Before production edits, preserve the pre-change build, immutable 0.1.16 bytes and the matching workload/provenance. The historical diagnosis is under `/home/siredvin/artifacts/tweaked-computers/idle-monitors-diagnosis-2026-10-27`; it is an idle controlled reproduction, not active/full-pack acceptance.
2. Introduce compatible, versioned scheduling metadata and one-time synchronized enrollment without changing guest API version or world identities. Preserve pending jobs and current fronts; do not mutate storage in `on_load`.
3. Extend `tools/monitor_upgrade.py` and `tests/monitor_upgrade_engine.lua` with an explicit 0.1.16→candidate case while preserving their existing 0.1.4/2.0.77 historical path. The current runner is hard-pinned to 0.1.4 and cannot be invoked unchanged with 0.1.16. Verify real saved/current version markers; renaming a ZIP does not constitute an upgrade.
4. Exercise upgrade and subsequent ordinary cold loads in base/Space Age against the packaged candidate, covering settled fronts and unfinished work without startup replay or credit renewal. Run the full affected contracts and matched idle/active measurements before documenting acceptance.
5. For visual/interaction or multiplayer claims, use a complete licensed 2.1.23 client and matching data with isolated saves/config; verify actual windows and connected-peer behavior separately. Missing prerequisites leave those gates open rather than justify a waiver.
6. Preserve verified evidence outside git/expiring scratch, excluding distributions, credentials and the user's private save. Rollback restores the backed-up pre-upgrade save together with its matching old mod archive; do not promise that a newer saved representation can be downgraded in place. Release authorization/version allocation remains a separate workflow.
