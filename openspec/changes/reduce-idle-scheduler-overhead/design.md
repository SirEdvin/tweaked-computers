# Design

## Context

See `proposal.md` for the measurements and motivation. Current state:

- `scripts/scheduler.lua:105-113` (`phase`) runs on every tick for each of 4 phases. It builds and sorts a hook-name list, then calls every hook through a fresh closure inside `try_maintenance` (`pcall`) with a `spend(1)` maintenance charge. `M.tick` also allocates `due`, a `ready_round` closure and two `M.maintenance` spend closures on every tick.
- Most hooks already return early when empty, but they reach that point only after `pcall(registry.maintenance_next, ...)`, clock validation or table work. Some do real work with nothing pending: `monitor-world` (`scripts/monitor-presentation.lua:493`) allocates `proofs`/`order` tables, requests render work and sorts; `ui-dashboard` (`scripts/ui/dashboard.lua:204`) sorts all session indices; `01-network-output-authority` copies its owner list.
- `device-status-art` (`scripts/device-art.lua:11-31`) redraws a running computer's sprite every 10 ticks and re-arms a 10-tick `art` deadline. `prototypes/devices.lua:13-21` already slices the `blinking` animation sheet into per-frame sprites.
- `compiler.run` (`scripts/runtime/compiler.lua:267-301`) calls `environment.new` and `runtime.services` for every callback. These rebuild about 25 environment closures, the stdlib namespaces, every API method closure and the peripheral provider's per-callback caches (`scripts/services/peripheral.lua:94`).
- Profiling (diagnostic archive, 1-minute chest run): idle ticks allocate about 10 KB each. Identical report callbacks take between 0.35 and 4.5 ms. `environment.new` alone ranges from 0.02 to 3.2 ms with the same allocation, which is consistent with garbage-collection steps landing there.

## Goals / Non-Goals

**Goals:** idle ticks that call no hooks and allocate nothing; hooks that run only on ticks where they have work; a status blink that needs no script work; less allocation per callback through scaffolding that is invisible to the guest; a reproducible chest benchmark.

**Non-Goals:** changing which work a hook does once it runs; changing UI cadences (15-tick viewers), timer semantics, fairness or budgets; caching Console environments; persisting or caching guest globals/locals; replacing the deadline heaps.

## Decisions

### 1. Required readiness check per hook, derived from synchronized storage

`register_phase(phase, name, fn, ready)` takes a required `ready(root, tick)` function. The scheduler calls `ready` directly, without `pcall` and without a closure. It enters the existing `try_maintenance` path, with its `spend(1)`, only when `ready` returns true. `ready` reads only state that the hook already keeps in `storage`, so every peer computes the same answer after save/load or late join.

Contract for `ready`: no allocation, no mutation, no native API calls except the minimum `ready` needs, and constant time. If it meets state it cannot interpret (wrong type or version), it returns true, so the hook's existing validation and `scheduling_diagnostic` path still runs.

Planned readiness per hook (confirm each against the hook's early returns during implementation):

| Hook | Ready when |
| --- | --- |
| lifecycle `00-physical-observation` | head of the `physical` deadline heap is due |
| lifecycle `01-clone-components` | `root.pending_clone_ports` is non-empty |
| lifecycle `01-network-output-authority` | the owned-output index is non-empty |
| lifecycle `02-computer-undo` | `root.scheduler.undo_pending` |
| lifecycle `02-monitor-groups` | monitor topology dirty, unfinished group job, or monitor state not yet initialized |
| lifecycle `02-native-radar-adoption` | adoption order is non-empty |
| sample `logic-input` | observer order is non-empty |
| notifications `monitor-events` | touches or resize jobs are pending |
| notifications `peripheral-topology` | topology order is non-empty |
| render `device-status-art` | head of the `art` heap is due |
| render `kv-reclamation` | head of the `kv` heap is due |
| render `monitor-world` | presenter has jobs, orphans, retired fronts, work lanes, shells or a dirty layout, or a previous render demand still needs withdrawal |
| render `program-editor` / `ui-peripheral-inspectors` | `tick % 15 == 0` and head of the `editor`/`inspector` heap is due |
| render `ui-dashboard` | `root.dashboard_sessions` has an entry, or chart presentation still has states, a pending surface deletion or a surface to reset |

Alternative considered: subsystems call `scheduler.wake(name, tick)` at every mutation point. Rejected. It needs dozens of new call sites, and a single missed wake silently drops work. Readiness derived from existing state cannot drift from that state.

Alternative considered: make each hook's own early return cheaper. Rejected as insufficient. The per-hook framework cost (closure, `pcall`, charge, sort) would remain.

### 2. Static order and lazy allocation in the scheduler

Each phase keeps an array of `{name, fn, ready}` that is sorted once by name inside `register_phase`. `M.tick` creates the maintenance `spend` closure, the `due` list and the `ready_round` admission closure only when it actually needs them: a hook is ready, a timer is due or the ready set is non-empty. The existing ledger and clock validation stays; it reads state but does not allocate. The relative order of lifecycle → sample → notifications → timers → dispatch → render does not change.

Skipped hooks no longer pay `spend(1)`. This revises internal maintenance charges, which `Deterministic revised resource accounting` already permits, and it is deterministic on all peers.

### 3. Native status animation

Define `animation` prototypes `tc-status-<kind>-<direction>-blinking` from the existing `image.states.blinking` sheet. `refresh` draws them with `rendering.draw_animation{animation_speed=0.1, animation_offset=0}`, which gives frame `floor(tick/10) % 4`, the current script formula. `refresh` then returns no deadline for the blinking state. Other states keep their single sprites.

Existing saves need no special migration. Pending 10-tick art deadlines fire once, `refresh` replaces the old sprite object because its name differs, and no new deadline is armed. Keep the per-frame `-blinking-N` sprite prototypes in this change, because removing a sprite that a saved render object references is a separate compatibility question.

Verify on the pinned 2.1.23 client that the alignment holds. If the engine's frame phase differs, choose `animation_offset` so the frames match; the cadence is the requirement.

### 4. Run-scoped host scaffolding

Split `environment.new` into:

- `build(shell)`: constructs the stdlib wrappers, namespaces, `print`/`pcall`/`xpcall`/`tostring`, API namespace proxies, service wrappers and label/protected maps. All closures read per-invocation values from one mutable `frame` table instead of from upvalues.
- `bind(scaffold, context, services_frame)`: resets the frame for a single callback. That covers the admission reservation function, poison/closed/line state, output sink, host-error and binding maps, service frames, exports/constructing, and a fresh globals proxy whose `__index` reads the shared env and the frame's exports.

Service providers keep their signature, but `tick` may be a number or a reusable `{tick=}` frame. They register per-callback setup with `guard.on_bind`: the runtime provider obtains a fresh `principal.proof`, and the peripheral provider resets `inventories`, `availability`, `authorized` and the weak `handles` map and wraps the new authority invalidation. Guards without `on_bind` (existing test doubles) run that setup immediately. `protected` and `labels` become weak-keyed, so per-callback facades do not accumulate in reused scaffolding.

Cache: a process-local table in `compiler.lua` keyed by computer id. An entry is valid only when the record, `run_id`, `generation` and the active plan's source string all match. Runtime settings only change admission numbers that closures read live, so no setting is captured at build and no settings epoch is needed. Lookup checks all keys, so a missed invalidation can only cause a rebuild, never stale reuse. A registry cleanup hook drops the entry on run retirement and removal to bound memory. The cache is never written to `storage`, and `on_load` never touches it.

Admission equality: building charges nothing. It counts the namespaces it creates, and every bind charges that total in one reservation, on the warm and the cold path alike. The single-use `environment.new(context, ...)` path charges the same total at the end of `initialize`. Refusal can move from inside the namespace sequence to that one reservation; `Deterministic revised resource accounting` permits this. `compiler.run` keeps its `admission.reserve(context,'compile', ...)` unchanged on both paths. So a peer with a warm cache and a late joiner with a cold one charge and refuse identically.

Each callback still does `load(executable.generated, ..., globals)` and `construct`. Guest top-level locals, upvalues and exports are therefore fresh, and so are the guest's own tables.

The Console keeps `environment.new`, implemented as `bind(build(shell), ...)`, so the Console contract does not change.

Alternative considered: persist or retain guest globals across callbacks. Rejected. Factorio does not save closures, so a joining peer or a reload would diverge and desync.

### 5. Reproducible chest benchmark

Add a `chest/poll` case (periods 30 and 600) to `tools/scheduling_benchmark.py` and its workload to `tests/scheduling_benchmark_engine.lua`. Base it on the recovered harness: four chests, 20 items, one logic handler, `computer.every(period,"report")` printing each entry, and audits of the Console output and native signals. The harness injects fixtures into a copy of the archive, so the same case runs against the baseline archive built from `main` before this change.

## Risks / Trade-offs

- [A readiness check misses a work source, so the hook never runs] → Every hook gets a test that creates its work on an otherwise idle tick and asserts the hook runs that tick. Unknown state returns true (fail open).
- [Reused scaffolding leaks per-callback state] → The guest-freshness, authority-per-callback and warm/cold equality scenarios run in headless cold reload and in connected late join. Frame reset is one function that covers every per-callback field.
- [Warm and cold charges diverge] → Construction charges are recorded and replayed, never recomputed. A fixture compares exact ledger totals and refusal positions on both paths.
- [Native animation phase differs from the script blink] → Verify in the full client; adjust `animation_offset`.
- [Provider refactor touches many service methods] → Mechanical change (read `frame.x` instead of upvalue `x`), covered by existing service contract tests.
- [Zero-allocation assertion is brittle] → Measure only across `scheduler.tick` itself, which needs no allocation when it calls no hook and no GC step can start. Any allocation fails the test with the measured delta.

## Migration Plan

No storage schema change. Status-art deadlines convert as described in decision 3. Rollback to the previous release works, because old code re-arms 10-tick art deadlines on the next state change and ignores animation render objects it did not create. Any running computer's art refreshes on its next state change.

## API Review

The `lua-api` artifact is skipped deliberately because API Impact is `none`. No guest-visible function, field, error or limit changes, and no canonical `api/*.d.lua` file changes.
