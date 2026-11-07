# Proposal

## Why

The chest benchmark (one computer, one logic handler, four chests, 20 items, report every 600 ticks) costs 0.115 ms per tick on average in the mod scheduler. About 96% of that cost falls on ticks where nothing is due. `demand-driven-device-scheduling` removed per-device scans but kept every phase hook running each tick, on the assumption that an empty-lane check is cheap. The measurements show that assumption is wrong. On an idle tick the 16 hooks and the phase framework (per-tick name sort, closure, `pcall` and maintenance charge per hook) together cost about 0.09 ms and allocate about 10 KB. That garbage makes report ticks vary between 0.35 and 4.5 ms for identical work, because garbage collection lands on the next large allocation. Most of that falls on the per-callback environment rebuild. The running-computer status light adds a script redraw every 10 ticks.

## What Changes

- The scheduler skips a hook entirely on a tick where that hook has no due or pending work. Each hook declares a cheap synchronized readiness check, derived from storage it already keeps. The hook body, its `pcall` wrapper and its maintenance charge run only when the check reports work.
- Hook order is fixed when the hook registers. The scheduler no longer builds and sorts name lists, creates per-hook closures or allocates timer/ready tables on ticks that have no due work.
- A tick that has no due timer, ready computer or pending subsystem work performs only constant bookkeeping and allocates no Lua memory.
- The running-computer status light becomes a native engine animation. It keeps the same four frames, the same 10-tick frame cadence and the same tick alignment. Script code changes status art only when a device's operational state changes.
- Saved-program callbacks reuse host-side scaffolding (stdlib wrappers, API namespaces, print/pcall wrappers, service method closures) for the lifetime of one computer run. Each callback still loads the program fresh, so guest globals, locals and upvalues remain fresh, and authority, admission context and per-callback proofs are rebound for every invocation. The cache is process-local and never affects synchronized state: warm and cold paths charge and refuse identically, so saves and late joiners stay deterministic.
- The chest workload becomes a reproducible case in the repository's scheduling benchmark, so baseline and candidate archives can be compared with an unchanged harness.

Not changed: guest-visible execution semantics, public Lua API, resource ceilings, timer/dispatch fairness, Console command execution (still fully rebuilt per command), subsystem behavior, UI cadence and save format.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `computer-runtime`: add constant, allocation-free idle scheduling and run-scoped, invisible reuse of host scaffolding across callbacks.
- `device-visual-identity`: running status animation is engine-driven; script art updates happen only on actual state changes.

## Impact

- Code: `scripts/scheduler.lua` (hook registration, readiness checks, idle fast path), each `register_phase` caller (`scripts/lifecycle.lua`, `scripts/blueprints.lua`, `scripts/computer-undo.lua`, `scripts/network.lua`, `scripts/services/{peripheral,monitor,logic,kv}.lua`, `scripts/rendering.lua`, `scripts/monitor-presentation.lua`, `scripts/device-art.lua`, `scripts/ui/{editor,peripheral-inspector,dashboard}.lua`), `scripts/runtime/{compiler,environment,computer,shell}.lua` and `scripts/services/peripheral.lua` (run-scoped scaffolding), `prototypes/devices.lua` (status animation prototypes). Pending 10-tick art deadlines in old saves fire once and convert; no storage migration.
- Tests: structural no-hook/no-allocation idle assertions, readiness-check coverage for every hook, warm/cold and late-join equality for reused scaffolding, status animation in the full client, and a matched chest benchmark.
- Tooling: chest case in `tools/scheduling_benchmark.py` and its engine fixture.
- No new dependency, setting, public API or larger budget. Maintenance-ledger charges on idle ticks decrease; existing specs already permit revised internal charges.

## API Impact

Status: none
Reason: No guest-visible function, field, argument, result, error or limit changes. Reused scaffolding is host-internal and gives the same guest behavior as fresh reconstruction.
Compatibility: Existing programs and saves keep working without migration.
Reviewed-source: c6029ab0fc8b06ab51d6d04ed6aa92e101dad0c1878b6ce9c06bc4e22de3caac
