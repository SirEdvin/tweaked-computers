## Why

Two host costs in the callback path are much larger than the work they protect. Both were measured on main `ec42b9b` (0.1.22) with the headless 2.1.23 engine on 2026-11-10.

**Repeated source validation.** Each callback validates its source again. A shared cache with 8 entries hides this cost only while 8 or fewer distinct sources take turns. Hot microbenchmark, one empty timer callback for each computer on each tick, 1.6 KB programs:

| Distinct running programs | Time for each callback | Lua memory for each callback |
| --- | ---: | ---: |
| 8 | 175 µs | 14 KB |
| 9 | 10.3 ms | 1.6 MB |
| 16 | 10.8 ms | 1.6 MB |

One validation with a cache hit takes 3.1 µs. One validation with a cache miss takes 11.5 ms. Sixteen computers with one identical source take 201 µs for each callback.

**Proof invalidation by `computer.*` calls.** Each `computer.*` call discards the callback-local authority proofs. The next check reads the owned ports and wire connectors again. The next peripheral call walks the wire network again.

| Measurement | Current | With the proof kept (ablation) |
| --- | ---: | ---: |
| One `computer.getTick()` call, hot | 12.8 µs, 0.65 KB | 3.4 µs, 0 KB |
| Six-line stock display, terminal, update tick median (two runs) | 1.86 ms, 1.87 ms | 1.66 ms, 1.68 ms |
| Six-line stock display, graphics, update tick median (two runs) | 1.51 ms, 1.50 ms | 1.24 ms, 1.26 ms |
| Lua memory for each update, terminal | 131 KB | 107 KB |
| Lua memory for each update, graphics | 111 KB | 86 KB |
| Network walks for each update (instrumented profile) | 2 | not profiled |

The stock program calls `peripheral.wrap`, then `computer.getTick()`, then the monitor. The same unchanged archive gives 1.66 ms to 1.68 ms (terminal) and 1.23 ms to 1.28 ms (graphics) when the program calls `getTick` before `wrap`. Thus the second walk is the cost.

**Control: chest report.** The chest program makes no `computer.*` call and runs alone. This change must not change its numbers:

| Case | Report tick | Other ticks (median) |
| --- | ---: | ---: |
| `chest/poll-30` | 0.62 ms median, 0.72 ms mean (120 reports) | 0.019 ms |
| `chest/poll-600` | 1.00 ms mean (6 reports) | 0.020 ms |

Evidence: `/home/siredvin/artifacts/tweaked-computers/exec-architecture-analysis-2026-11-10/`. The hot microbenchmark runs `scheduler.tick` in a loop without real ticks. The stock and chest values come from `tools/monitor_performance.py --program` and `tools/scheduling_benchmark.py`. The ablation changed one line in an archive copy and is not a reviewed implementation.

## What Changes

- A saved-program callback does not validate its source again when its run still holds reusable scaffolding for the same exact source. It uses the validation result that the scaffolding already holds. A peer without that scaffolding (late join, reload) validates the source one time, without a compilation charge, as it does now.
- The shared process-local source cache holds as many entries as the active-computer limit (64) instead of 8. It still serves activation, validation, first callbacks and Console commands.
- These `computer` methods keep the callback-local authority proofs: `getID`, `getLabel`, `setLabel`, `getTick`, `getLimits`, `getState`, `setState`, `deleteState`, `log`, `on`, `off`, `after`, `every`, `cancelTimer`. The rule applies to saved-program callbacks and to Console commands. `computer.stop` and each unclassified operation keep the current invalidation.

Not changed: results, errors, work charges, limits, settings, save format, the public Lua API, reachability rules, the ownership check on each call, and proof lifetime (one invocation).

Not in this change: timer and event delivery cost, physical-observation cost, and other fixed callback overhead. Their causes are not isolated.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `computer-runtime`: later callbacks of a run reuse the run's source validation result. The listed `computer` methods preserve callback-local authority proofs.

## Impact

- Code: `scripts/runtime/compiler.lua` (validation reuse, cache capacity), `scripts/runtime/computer.lua` (stable method classification).
- Tests: `tests/runtime_scaffold_engine.lua`, `tests/compiler_cache_contract.lua`, `tests/shell_contract.lua`, and a discovery-count contract.
- Docs: `docs/computer-runtime.md` (reviewed-boundary table, scheduler section).
- Storage: none. The scaffolding and the source cache are process-local and are never saved.
- Memory: the shared source cache can hold 64 entries instead of 8 (see design.md).

## API Impact

Status: none
Reason: No guest-visible function, field, argument, result, error, work charge or limit changes. `api/peripheral.d.lua` already states that only operations that can change proof assumptions invalidate a proof.
Compatibility: Existing programs, Console commands and saves keep working without migration.
Reviewed-source: 4a25884e04dfa2360d334ac1999427101809b1c98a54cb33aeb561273224bc91
