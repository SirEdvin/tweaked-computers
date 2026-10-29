# Proposal

## Why

Factorio 2.1.23 running released mod 0.1.16 spends substantial time maintaining unchanged monitors: a controlled 144-tile scene with a stopped computer and no radars averaged 7.094 ms per scheduler tick, versus 0.141 ms without monitor tiles on the same host. Existing damage tracking and buffered rendering do not prevent repeated full physical checks, grouping scans and presenter polling, so active programs inherit avoidable maintenance work too.

## What Changes

- Schedule logical displays or synchronization groups that need work, reusing existing damage tracking, pending snapshots, rendering jobs and retirement work rather than adding a second rendering system.
- Preserve synchronous peripheral calls; queue presentation work, not commands. Deduplicate wakeups and coalesce only pending work under the existing buffering rules.
- Reconcile monitor grouping when relevant physical state or grouping policy changes, not by rebuilding the complete tile signature every tick.
- Replace duplicate monitor physical-maintenance walks with one minimal live observation pass per actual tick. Preserve power-loss/restoration behavior, silent physical-change detection and fresh validation at actual operations; do not introduce delayed idle-screen behavior.
- Wake affected work for settings paste, placement/removal/rotation/clone, ownership changes, power transitions, synchronization ownership/path changes, migration and unfinished retained jobs—not only drawing calls.
- Add structural regression gates for unnecessary scans and repeated work, plus serial before/after timing reports for idle, partially updating and continuously animated 144-tile scenes. Timing reports are required; no fixed millisecond or percentage threshold is a pass/fail requirement.
- Add a monitor API companion documenting unchanged public methods and the new scheduling guarantees. No new guest methods, configuration knobs, dependencies, capacities or relaxed resource budgets are proposed.

## Capabilities

### New Capabilities

None. Reuse the existing monitor and physical-lifecycle capabilities.

### Modified Capabilities

- `monitor-display`: Demand-driven presentation and topology reconciliation; deduplicated wakeups; preserved buffering, synchronization and cold progress; observable work-elision acceptance and honest timing reports.
- `device-lifecycle`: Consolidated monitor observation and change notification without duplicate full maintenance, stale authority or changed power/physical behavior.

## Impact

- Main implementation areas: `scripts/services/monitor.lua`, `scripts/monitor-presentation.lua`, `scripts/monitor-model.lua`, `scripts/rendering.lua`, `scripts/lifecycle.lua`, `scripts/registry.lua`, `scripts/lifecycle-data.lua`, `scripts/device-art.lua` and relevant event wiring in `control.lua`. Existing scheduler phases and peripheral validation remain the integration boundaries.
- Verification: extend the native monitor/component/state/animation suites and packaged harnesses; add a focused structural/idle-work fixture and paired measurement wrapper where existing runners cannot express the new assertions. Include upgrade from immutable 0.1.16 and separate-process save/reload.
- Public API and ordinary screen behavior remain compatible. Non-monitor devices, radar enrollment, circuit APIs and program execution semantics are outside the optimization scope.
- This change targets the declared Factorio 2.1.23 base and optional Space Age configurations. Planning does not constitute implementation, runtime acceptance, publication authorization or a promise of particular client FPS/UPS.
