## Context

Profiling of the chest benchmark (poll-30, 100 reports) on `ff02940` attributes about 1.03 ms to each report dispatch. `print` costs about 17 µs per call with instrumentation: Console append 4.7 µs, argument conversion 3.6 µs, three work charges about 4.2 µs and owner checks 2.6 µs. `run.load` costs about 0.16 ms per callback. Evidence: `/home/siredvin/artifacts/tweaked-computers/report-tick-breakdown-2026-11-07/`.

`reduce-idle-scheduler-overhead` introduced run-scoped scaffolding. A scaffold builds one environment, so `env.globals` is the same table for every callback of the run. The validator rejects `_ENV`, `_G` and `debug`, so guest code cannot change the chunk's only upvalue.

## Goals / Non-Goals

**Goals:** remove the per-callback `load`, the safe-`tostring` call for string print arguments and the Lua-loop shift on single-entry Console eviction, with identical guest behavior and charges.

**Non-Goals:** merging the three print work charges (it changes the charged prefix of a refused print), relaxing per-print owner checks, caching `peripheral.find` network discovery, changing Console command execution.

## Decisions

### 1. Keep the loaded chunk in the scaffold entry

`compiler.run` stores the function returned by `load` on the scaffold entry and executes it again through `env.construct` on later callbacks. The scaffold key already includes computer identity, run, generation and source, and cleanup already drops the entry. Executing the chunk again creates new declarations and closures, so freshness does not depend on loading.

The compile admission charge stays before the load and is charged on every callback, so warm and cold callbacks still charge identically. Callbacks without scaffolding (`owner=nil`) and Console commands keep loading every time.

Alternative considered: a global cache keyed by source text. Rejected: the chunk is bound to one environment, and a scaffold is the only owner of that environment.

### 2. String fast path in `print`

A string argument is its own safe `tostring` result, so `print` uses it directly. Every other type keeps the existing safe `tostring`.

### 3. Native single-entry eviction

When the computed eviction prefix is exactly one entry, `computer.log` removes it with `table.remove(logs,1)`. Larger prefixes keep the existing single-pass compaction, so a lowered entry limit still costs linear work. Charges, byte accounting and the truncation flag are unchanged.

## Risks / Trade-offs

- [Scaffold environment becomes per-callback in a future change, so a reused chunk would point at a stale environment] → The comment at the cache site states the dependency, and `tests/runtime_scaffold_engine.lua` counts loads for warm, cold and new-run callbacks.
- [Guest state leaks through the reused chunk] → The chunk's only upvalue is `_ENV`, which the validator forbids. Declarations and helper closures are re-created on every execution. Existing fresh-state and warm/cold contracts cover this.
- [Measured savings are smaller than estimated] → Report the matched chest benchmark result. Claim no speedup beyond it.

## Migration Plan

No storage change. Old saves load unchanged. Rollback is a code revert.
