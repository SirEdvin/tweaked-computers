# Design

## Context

See [proposal.md](proposal.md) for motivation and [lua-api.md](lua-api.md) for the externally visible compatibility changes. Baseline inspected: `63612f9c109d1a3c21d3029b7d2c32df85f4ed49` on planning branch `plan/demand-driven-device-scheduling`. This branch also contains the independent `function-only-programs` proposal; neither change has been implemented here. Reconcile shared runtime/Console spec hunks when applying them, without coupling scheduling to a source-language rewrite.

Observed source:

- `control.lua:69` owns the single production tick callback. `scripts/scheduler.lua:193-248` validates ledgers, executes lifecycle/sample/notification hooks, walks `root.order` for timers and dispatch, then renders. Hook names are sorted in each phase.
- `scripts/services/logic.lua:228-331` discovers subscriptions by scanning computers, sorts them, reads selected inputs and then clears resync flags with another global walk. It already shares samples within a tick, but reconstructs demand every tick.
- `scripts/services/peripheral.lua:337-396` discovers running topology consumers and output owners through registry walks. Native adoption (`scripts/network.lua:111`) similarly rebuilds computer roots.
- `scripts/lifecycle.lua`, `scripts/device-art.lua` and `scripts/services/kv.lua:350` perform broad maintenance walks. `scripts/monitor-presentation.lua` already demonstrates retained pending-work membership; clone/undo queues also already exist.
- `scripts/device-definitions.lua:3-22` identifies the nine custom composite families with electrical wattage. Radars/speakers are separate native carriers.
- `scripts/ui/editor.lua:605` and `scripts/ui/peripheral-inspector.lua:367` inspect connected players every 15 ticks. Dashboard refresh already starts from sessions but revisits their complete definitions each tick. Running computer status art changes on 10-tick animation boundaries; monitor cursor blink is already native rendering behavior.
- The current harness (`tools/smoke.py`) requires Factorio 2.1.23. Some older capability prose and the host-local AGENTS examples still name 2.0.77; do not use that older executable for new acceptance without reconciling the actual manifest/harness pin.

The inspected official 2.1.23 runtime API has one handler registration per mod/event and no general circuit-value or electricity-change event. `LuaEntity.get_signals_changed(wire_connector_id, tick_of_last_check?)` is a polled hint, can return false positives and returns nil for a missing connector. It is not an entity-owned event callback. Use only the pinned contract; native per-entity engine scheduling is not exposed to the mod.

## Goals / Non-Goals

Goals: make demand explicit at mutation boundaries; eliminate whole-registry work discovery from ordinary ticks; maintain tick-level subscribed input observation, live authority, safety cleanup, fair execution, complete frames and synchronized persistence. Every recurring hook must have an owner, trigger and retirement condition.

Non-goals: a second scheduler, actor/ECS framework, public task API, guest coroutines/continuations, source-format changes, new dependencies/settings/limits, arbitrary budget increases, removal of native radar/speaker electricity, or a promise that all native state changes have events. Planning validation is not engine performance acceptance.

## Decisions

### 1. Keep one dispatcher; move eligibility to the subsystem that knows it

Keep `scripts/scheduler.lua` and existing phase/admission facilities. Static phase hooks may remain: a constant-size check for an empty lane is cheap and does not visit entities. Do not dynamically register one native callback per device or introduce a parallel bus. Remove the precharged full registry walks along with the walks themselves; replacing them with unmetered discovery would not solve the problem.

Use small retained structures under the existing versioned scheduling state:

| Work class | Eligibility owner and trigger | Retirement |
| --- | --- | --- |
| Runnable computers | Runtime event publication/activation and Console ingress | Both program and shell queues empty, or generation/identity retired |
| Deadline entries | Timer changes, due physical/topology observations, UI cadence, status animation, KV expiry | Canceled/replaced deadline or no future demand |
| Watched inputs and reverse subscribers | Accepted logic registration; key is physical identity/generation + input color | Last subscriber removed; run/binding/endpoint invalidated |
| Owned-output safety | Successful output replacement, including empty-bank ownership if existing semantics retain it | Clear/replacement/owner retirement |
| Topology interests and native adoption | Attach/detach subscribers, modem receive interests, active bindings, explicit discovery and open network UI | Last interest/pending request removed |
| Dirty/pending service work | Physical invalidation, clone/undo work, grouping, touches/resizes, model changes, cleanup | Work committed/canceled/retired |
| Open UI sessions | Open/close/tab/player-lifecycle events plus dirty content and existing cadence | Closed, unavailable or replaced exact session |

Membership is host-owned plain data, not functions, iterators, native executable handles or guest authority. Maintain reverse links only where cancellation/fan-out otherwise requires a global search. One live key per owner/work kind prevents duplicate wakeups. Validate identity, run/session generation and current demand before servicing an entry. Unsupported metadata is recoverable and inert, not silently rebuilt by resetting user data.

Use a small scheduler-local indexed deadline queue for the required fixed work kinds, not a generic job framework. An owner has at most one next deadline for a given kind. For computers, retain the earliest timer deadline and reuse the existing bounded timer advancement/order/coalescing logic when due; recompute only that computer's next deadline on registration/cancellation/advancement. Database expiry can likewise retain a next-due key/deadline without scanning every database per tick. Update/delete indexed entries rather than accumulate unbounded cancellation tombstones. Stable tie-breaks use due tick, work kind and existing identity/sequence ordering.

Alternative: keep the global scans and add early returns. Rejected because cost remains proportional to idle population. Alternative: merely switch all devices to `on_nth_tick`. Rejected because it loses required signal responsiveness and bunches unrelated work.

### 2. Preserve the full coarse tick cycle and make each lane explicit

Editable overview: [tick-cycle.excalidraw](tick-cycle.excalidraw). Vector preview: [tick-cycle.svg](tick-cycle.svg). Raster preview: [tick-cycle.png](tick-cycle.png). The drawing is the proposed complete mod cycle, not a claim of implemented behavior or Factorio's internal engine phase order.

1. Entry/admission: validate retained scheduler/ledger header and monotonic tick, reject duplicate same-tick execution, freeze existing render reservation and retain spent credits. Pull only due deadline heads into their owner lanes; extracting a future deadline never visits its device.
2. Lifecycle/safety: service targeted invalidations and due physical observations; validate active output ownership before sampling/dispatch; progress pending clone, undo, native-adoption and monitor-group work. Existing event handlers remain responsible for immediate non-power invalidation. Optional repair may defer; safety must not authorize stale effects.
3. Signal sample: inspect only actively watched input/color entries. Independently check selected-path authority and connectivity, obtain an inventory when changed/initial/resync, compare effective values and admit notifications in stable registration order. No subscription-discovery walk and no unrelated resync-reset walk.
4. Notifications: process pending monitor touch/resize deliveries and due/pending peripheral attach/detach work. Keep snapshot, generation, channel, recipient order and partial-progress safeguards. Events enqueue executable work; they do not invoke callbacks inline.
5. Timers: advance only due computer timers. Preserve absolute scheduled ticks, creation ordering, cancel-after-enqueue, missed-interval coalescing and alignment. A refused due item retains demand and receives another fair opportunity, not a fresh deadline pretending it was never late.
6. Execution: take a stable snapshot of the ready rotation for this round, give each eligible computer at most one program/Console item, and retain existing arbitration and shared admission. Requeue remaining work at the back. New ready entries produced during dispatch join a subsequent round; the snapshot prevents recursive or same-round repeated execution. A refused head must not monopolize the lane.
7. Deferred work/presentation: process dirty status art or due animation transitions, due KV reclamation, pending monitor capture/prepare/commit/retire and due/dirty open editor, dashboard and inspector sessions. Snapshot monitors only after dispatch; retain complete-group barriers, native cursor blinking and fair bounded chart work.
8. Park: keep unfinished work and its paid progress, schedule its justified retry/deadline and remove completed membership. No end-of-tick registry sweep. With no demand only constant scheduler bookkeeping remains; idle physical observations still occur at their due bounded cadence.

The existing relative sample -> notifications -> timers -> dispatch -> presentation ordering is retained. Within lifecycle, move due non-power invalidations ahead of dependent safety proofs; explicitly test hook order rather than rely accidentally on new alphabetical names. Pre-admit necessary fail-safe cleanup and protect required sampling from optional maintenance within existing ceilings. When sampling genuinely cannot fit, keep existing explicit fault/cleanup, not an undisclosed missed sample. Deferred optional work rotates fairly rather than blocking every later deadline behind one expensive entry.

### 3. Complete existing-hook disposition

This inventory covers every production `register_phase` call found in the inspected source; no hook is left as an unreviewed fallback sweep.

| Existing phase / hook | Proposed work and trigger |
| --- | --- |
| lifecycle / `00-physical-observation` | Targeted lifecycle events/repairs plus staggered due non-power observation, within the existing topology envelope; necessary checks precede dependent use. |
| retired / `00-physical-power-loss` | Removed custom power sampling entirely. No replacement native-carrier power sweep. |
| lifecycle / `01-clone-components` | Existing pending clone ports only; enqueue on clone events, retire on adoption/destruction. A bounded related lookup while resolving actual clone work is allowed, not an idle scan. |
| lifecycle / `01-network-output-authority` | Incrementally maintained output owners only; preserve published fail-safe checks even when the owner has no executable item. |
| lifecycle / `02-computer-undo` | Existing pending undo settlement plus explicitly scheduled candidate-clear work; no retained undo-state visit once settled. |
| lifecycle / `02-monitor-groups` | Dirty topology and unfinished partition/group/retirement work only. Genuine regrouping may enumerate its affected component; do not use the global registry to discover idle groups. |
| lifecycle / `02-native-radar-adoption` | Pending computer-rooted discovery and due interested topology observations; no all-computer root rebuild, dormant radar scan or native power check. |
| sample / `logic-input` | Active watcher index only; shared native observation, independent subscriptions, no all-computer cleanup tail. |
| notifications / `monitor-events` | Pending touch and resize jobs plus indexed registered recipients; no settled-display scan. |
| notifications / `peripheral-topology` | Due interested computer/color bindings and existing unfinished transition jobs; do not poll every running computer. |
| scheduler timer walk | Earliest due deadline membership only; retain timer semantics and fairness. |
| scheduler dispatch walk | Ready computers only, with existing program/Console arbitration. |
| render / `device-status-art` | Dirty exact devices and due 10-tick status-animation transitions for running computers; monitor cursor remains native. |
| render / `kv-reclamation` | Due expiry/unfinished cleanup only; lazy expiry remains authoritative for every command. |
| render / `monitor-world` | Existing pending presenter model: dirty capture, prepare, whole-group publication, retire; remove electricity wakeups but retain non-power invalidation and selected-path proofs. |
| render / `program-editor` | Open owned sessions only, existing 15-tick cadence plus genuine dirty updates. No connected-player search. |
| render / `ui-dashboard` | Open viewers, dirty definitions and eligible visible charts; retain existing chart coalescing/bounds and viewer fairness. |
| render / `ui-peripheral-inspectors` | Open owned sessions only at existing 15-tick cadence; no guest subscription created for local inspection. |

Direct native event handlers in `control.lua` feed these memberships: build/revive/platform build, removal/death, clone/rotate, object destruction, settings paste/blueprint setup, undo/redo/deconstruction, force/surface changes, settings changes and GUI/player events. Guest host calls feed them through the existing runtime/service mutation boundaries. No tick-driven source execution is added to load or GUI handlers.

### 4. Treat signal observation as active interest, not computer activity

Incrementally update membership at `runtime.subscribe/unsubscribe`, logic-specific revoke, run retirement, replacement and endpoint destruction. Keep stable subscriber order without sorting all computers each tick. The exact input connector and selected discovery wire are different keys: share the native input result but never merge authority proofs across callers or colors. Sleeping execution does not suspend active input observation.

`get_signals_changed` is an optimization only. Call it on the actual selected input connector; nil, invalid identity or genuine proof failure is not an unchanged result. Fresh registration baselines, initial delivery, required resync and topology/connectivity changes force appropriate observations. Preserve effective-identity/count comparison, native optional fields, mutation isolation and direct-read freshness. Verify the pinned engine's connectivity-change behavior; if the hint cannot safely avoid a read, directly sample that watched input every tick instead. This fallback preserves the architecture because it still excludes unsubscribed inputs.

Do not introduce new signal-count limits, persisted inventory-processing jobs or proportional trusted-circuit payload charges. Existing accepted subscription counts, queue envelope/backlog protection and explicit sampling failure remain. Callback latency is distinct from sample cadence; overloaded callback queues cannot excuse dropping intermediate observed pulses.

### 5. Power removal must not remove physical validation

Remove active electrical helpers from `prototypes/devices.lua`, `scripts/device-definitions.lua` and composite construction/repair/snapshot paths. Keep compatibility prototype definitions only if needed to load supported historical saves, with no active consumption; synchronized migration removes only positively owned old helpers. Do not delete role sockets, wires, bodies or user entities by name/position guesses. Preserve one-item mining and blueprint/clone isolation.

Audit every `powered`, `has_power`, `sample_power`, `set_power` and `power_checked_tick` consumer. Some currently conflate electricity with physical validity. Replace electrical gates with the actual non-power validity/authority proof rather than simply forcing all checks true. Keep same-event revalidation for monitor operations/publication, generation checks, player authorization, wrapper revocation and last-writer cleanup. The public `powered` field remains true for valid custom endpoints as a compatibility value, not an authorization cache.

Do not modify `prototypes/radar.lua` or the native speaker energy settings. Runtime radar/speaker availability remains a live call-boundary query, and modem routing checks receiver power during real transmission eligibility. Open channels/subscriptions do not schedule power observation. Remove the periodic native checks from generic lifecycle paths while preserving targeted destruction/scope handling.

Retain the inert legacy `power_restored` registration name to avoid making otherwise valid source fail; it schedules no work and generates no new events. Existing already admitted events remain historical queue items. User documentation must clearly mark the changed behavior rather than promise brownout callbacks that can no longer occur.

### 6. Observations without native events remain narrow and scheduled

Physical movement/rotation/scope changes and circuit rewiring do not all have complete notifications. Use existing targeted notifications first, and due non-power physical observation within `topology_latency_ticks` for idle composites. Stagger due times deterministically; no new latency setting or longer release promise. An idle per-device check at an explicit due deadline is allowed; reconstructing the due set by visiting all devices every tick is not.

Authority-bearing work is not idle: output owners retain `fail_safe_latency_ticks`, selected monitor groups retain their authority maintenance, and active signal subscriptions retain every-tick observation and fresh selected-path checks. Topology attach/detach watchers and modem receive interests own bounded discovery work, while an explicit discovery/call proves current access immediately even without a watcher. Pending/unavailable proof must remain explicit, never a false empty inventory or cached permission.

Retained static images can reflect a silent non-power physical change until due observation, but fresh calls, touches and publication must refuse invalid geometry immediately. This is the accepted delayed-idle-observation trade-off, not permission to weaken safety. Status animation remains due work even for a waiting running computer: preserving its existing 10-tick visual cue is not a hidden per-tick execution poll.

### 7. Persistence and implementation ordering

Persist ordering/membership needed for deterministic ordinary reload and late join. Control parsing installs trusted hooks only. `on_load` does not mutate world/storage, rebuild authoritative queues, compile guest source or execute callbacks. One-time init/configuration migration can inventory saved records before ordinary ticking. Keep durable source/state and diagnostic paths for unsupported representations.

Implement power/membership migration and a usable runtime slice together before spreading the optimization to every hook: a waiting subscribed computer must observe and run on change, an unsubscribed computer must have zero signal work, and an inactive computer's far-future timer must still wake correctly after cold load. Then remove remaining broad hook scans while retaining those tests. This is an implementation milestone, not authorization to implement during proposal generation.

## Risks / Trade-offs

- Lost wakeup or stale membership -> centralize updates at existing mutation/cleanup paths, use identity/generation checks, and regress cancellation, repeated dirtying, removal and cold boundaries.
- Safety cleanup starved by optional maintenance -> retain independent cleanup and explicit sampling-failure behavior, test under reduced fixture allowances without increasing production budgets.
- Native change hint misses a relevant connector transition -> test initial/resync, connect/disconnect/merge/split and one-tick pulses; use direct watched-input sampling when necessary.
- Ready-queue ordering changes cross-computer contention -> document stable rotation, preserve per-computer FIFO and one-item arbitration, and verify identical effects across peers and cold reload.
- Power helper removal damages saved composite ownership -> migrate exact owned helpers in isolation, verify native wires/roles/items and unknown-header recovery against old archives, and keep native carriers untouched.
- Lower recurring visit counts do not prove lower CPU time -> collect matched serial whole-scheduler timing distributions, including all-active and mixed workloads; report regressions and host contention. No invented percentage threshold or GPU-FPS claim.
- Existing canonical power requirements conflict with this change -> delta specs explicitly modify or retire them; implementation must update companion APIs, help, locale and fixtures together. Preserve unrelated scenario names/assertions.

## Migration Plan

1. Preserve an immutable baseline archive and copied historical saves with hashes. Apply only after explicit implementation authorization. Keep the other planning change independent.
2. Add versioned scheduler/membership migration through existing init/configuration paths. Validate old source/run/queue/ledger headers before creating demand; unsupported records remain inert and recoverable.
3. Remove only owned custom power helpers, initialize non-power physical validity, retain bodies/role sockets/wires and upgrade device/status metadata. Native radar/speaker bodies/settings/channels remain intact.
4. Populate ready/deadline/watch/owner/pending/UI membership once. Resume a legacy electrically paused running generation without startup; retain timer alignment and accepted events, request only the required legacy signal resync, and never resurrect already discarded transients or restart intentionally stopped/faulted runs.
5. Exercise separate-process upgrade and ordinary reload, including partial pending topology/monitor work, queued Console commands and spent same-tick credits. Verify connected-client deterministic order separately.
6. Package only the verified candidate with updated docs/help/examples. Keep evidence outside git and never include Factorio distributions. Roll back by restoring the copied pre-upgrade save with its matching old archive; in-place downgrade of migrated scheduling state is not promised.

## Implementation hook reconciliation

The baseline observations above remain historical. The current production hook
names, exact ordering, per-identity demand reasons and non-ordinary inventory
exceptions are reconciled in [the source hook audit](../../../docs/device-scheduling.md).
The drawing now identifies itself as an implementation map, not measured
performance or acceptance evidence. Direct per-tick watched reads are the chosen
fallback after the pinned-engine hint probes; the hint never suppresses an
observation. Open editor/inspector sessions use the fixed 15-tick deadline lanes;
Dashboard refresh reuses exact tab-definition identities and selected visible
chart references, preserving existing viewer/chart rotation.

## Evidence references

Pinned official runtime API inspected for planning: `https://lua-api.factorio.com/2.1.23/runtime-api.json` (`LuaBootstrap.on_event`, `LuaEntity.get_signals_changed`, event inventory). These are source/API observations, not execution receipts. The editable scene and previews explain the design; their JSON/import/rendering is validated independently. Implemented rows, remaining runtime/native/peer gates and the separately owned timing comparison are tracked in [tasks.md](tasks.md) with external checkpoint receipts; the diagram itself certifies none of those passes.
