---
type: runtime
title: Shared scheduling, timers and admission
description: Deterministic host phase ordering, retained real-tick credits, fair callback/timer scans and bounded maintenance deferral.
tags: [scheduler, admission, fairness, timers, budgets]
verified:
  - by: openwiki/0.7.1
    at: 2026-10-15T06:41:57.498Z
sources:
  - id: openwiki-source-6017f73285ae6bbf6c3d040a
    resource: repo://scripts/registry.lua
  - id: openwiki-source-03e30f27b8f4219a9e5d2085
    resource: repo://scripts/runtime/admission.lua
  - id: openwiki-source-0ddacafef71462f8b63089cd
    resource: repo://scripts/runtime/computer.lua
  - id: openwiki-source-0bf68f272e97a323da18a610
    resource: repo://scripts/scheduler.lua
generated: { by: "hermes", at: "2026-10-15T06:41:57.498Z" }
---

# Shared scheduling, timers and admission

## One scheduler, ordered host phases

Normal `control.lua` has one `on_tick`, not one handler per computer. `scheduler.tick` first rejects unsupported registry/ledger headers or a backwards retained clock. It refuses same-tick replay through `scheduler.last_tick`. Before hooks can spend the maintenance pool, it reserves both bounded identity walks.

The effective flow is:

1. `lifecycle`: sorted registered hook names, including early physical power-loss checks, clone/output authority checks, monitor regrouping and physical reconciliation.
2. `sample`: logic input sampling; samplers must execute their own fail-closed refusal path even after earlier maintenance spending.
3. `notifications`: monitor/topology jobs.
4. Timer advancement across the ordered computer identities, using a rotating maintenance cursor.
5. Callback dispatch across identities using its own fair cursor; at most one dispatch per computer per real tick.
6. `render`: charged monitor world rendering, KV reclamation and editor/art presentation hooks. Render reservation prevents ordinary maintenance from consuming all retained drawing headroom.

Hooks are module-local functions registered during control parsing; the ordering state/cursors and accounting live in storage. If a hook relies on another phase hook, its actual phase and sorted name matter; import order is not an execution-order guarantee.

## Real-tick credits survive stops and saves

`admission.new` creates a plain ledger with version, real tick, aggregate total and per-identity `work`, `compile`, `allocations`. `context` clears it only when the real clock advances. Same-tick Validate, Run/Apply and callbacks share the same identity credits; deleting a computer or retiring a run never refunds them. Cold load cannot obtain a new budget from an empty ephemeral cache.

`reserve` validates amounts/context age and atomically checks both the per-kind machine ceiling and aggregate guest ceiling before updating counters. Guest admission excludes the host maintenance reservation. Compiler probes, fresh reconstruction and service work therefore contend for explicit shared resources rather than each receiving independent unlimited budgets.

Dispatch preserves aggregate headroom for one complete maximum-bounded callback. When neighbors leave insufficient headroom, the untouched queued run waits rather than being faulted solely for losing scheduling order. `E_BUSY` context admission also defers. A genuine compiler/callback failure faults the current run and executes teardown. Callback work is abstract admission units, not measured CPU milliseconds.

## Maintenance refusal is not a guest exception

`scheduler.maintenance` owns a separate retained per-tick spending counter. Its private refusal value is recognized only by `try_maintenance`; unrelated native errors are rethrown. Phase hooks either reserve a complete transition before publication or retain a cursor/job for retry. The sampler exception to phase precharge is deliberate: input/output safety must not silently skip the tick and leave old positive data authorized.

Physical dispatch demands both no physical error and `power_checked_tick == tick`. Logic output authority uses a separate prepaid clear path when witness proof cannot be admitted. Never replace these fail-closed checks with a stale cache to improve apparent throughput.

## Timer ordering and overdue intervals

Timers contain a named handler, absolute deadline, optional interval, copied payload and monotonic sequence. Durations are positive safe integers; timer IDs belong to a run. Pending queued one-shot timers count against capacity, and cancellation removes both timer records and queued notifications.

Timer advancement sorts by deadline then sequence. If a recurring notification is already queued, further overdue intervals update its `missed` count instead of generating an unbounded burst; the original scheduled tick stays intact. Recurring deadlines advance past the current real tick, with safe-integer overflow faulting rather than wrapping. Unpowered computers do not advance/dispatch timers until processing resumes; queued start/timer work survives the outage, so delayed processing coalesces explicitly rather than replaying startup.

## Extending safely and checking it

Use `register_phase` with a deliberate phase/name and bounded hook count. Reserve native work before changes and retain a plain job/cursor when a multi-tick job is necessary. Do not store function closures in storage or reset `last_tick`/ledger headers as a recovery shortcut. Changes to `limits.lua` affect compiler, scheduler and service safety; they are not a substitute for performance evidence.

`tests/computer_contract.lua`, `tests/computer_cold.lua`, service engine fixtures and `tests/integration_engine.lua` cover callback ordering, admission retention, coalescing and production interaction. The wiki-only change does not execute them. Maximum simultaneous-world performance, real client-visible latency and multiplayer joining are not established by configured limits or historical small workloads.

Related: [compiler/sandbox](compiler-and-sandbox.md), [runtime retained records](../architecture/runtime-and-state.md), [signal sampling/ownership](../services/signal-ownership.md), [monitor render jobs](../services/monitor-pipeline.md).
