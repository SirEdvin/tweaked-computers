# Demand-driven monitor maintenance validation

This report covers the `demand-driven-monitor-maintenance` implementation, not a
release or a merge. Target engine: **Factorio 2.1.23 build 87750**, base and optional
Space Age. The implementation does not change the mod version, guest APIs,
capacity settings, callback semantics or production budgets.

## Provenance and evidence boundary

Source starts at `3b5667a6e4868b99b6123a16a83abe5e551602cb`. There are no parent
implementation commits. Immutable released 0.1.16 has SHA256
`f7941bfcb8380222060112f1c8120d29efaf271085bb164cc96cc513340bd23d`;
the pre-change build has SHA256
`95fa7ef48ade7d1494a2f00ccb1ef75a943a87f92699205106ade6ad772ce826`.
They differ only in documentation, the peripheral-network/radar-modem canonical
specifications and the package manifest, not runtime or example bytes. Both are
retained and measured; neither was overwritten.

Receipts, immutable packages, command inventories and selected captures live
outside git under the task's durable evidence root:

```text
/home/siredvin/artifacts/tweaked-computers/
  openspec-campaign-2026-10-27-3b5667a/t_48587211/
```

The evidence ledger records each tested package separately. Early successful
cases are reusable only after a complete archive-entry comparison proves that
later changes are limited to other test fixtures, documentation and the package
manifest. They are not represented as a full matrix run on one later ZIP.
Structural instrumentation explicitly changes the copied provider/presenter
counter boundaries; phase attribution separately instruments scheduler hook
registration. Neither instrumented archive supplies whole-scheduler comparisons.

## Behavior and scenario mapping

| Gate | Existing or focused evidence |
| --- | --- |
| Idle, one-screen and all-screen work elision | `monitor_demand.py`, instrumented actual-tick fixture, both modes, ordinary cold idle and physical-change tail |
| Same-event authority and settings paste | `monitor_component_contract`, including move/direction/force/power/helper proofs and scale-resize notification |
| Synchronous model changes and immutable snapshots | `monitor_snapshot_contract`, `monitor_budget_contract`, `monitor_optimization_contract`, `monitor_buffer_engine` |
| Bursts, no-op rounds, later callback errors, bounded demand and fairness | `monitor_budget_engine`, `monitor_presentation_engine`, chart animation and modem/speaker competition |
| Idle Console revocation, temporary path blockage and exact wire binding | `shell_contract`, `shell_cold`, component and retained-state selection contracts |
| Idle, waiting, pending, preparing, ready-deferred and retiring cold states | Six `monitor_state_*` production-owner fixtures, separate native processes; exact saved graph, aliases, visibility and credits |
| Old save enrollment and ordinary reload | `monitor_upgrade.py` with immutable 0.1.16 and historical 0.1.4 paths; both modes |
| Placement/clone/rotation/removal and neighboring devices | `lifecycle_engine`, `integration_engine`, `rotation_engine`, `network_engine`, `art_engine`, focused physical-change tail |
| Notification, render and authority regressions | `monitor_feedback_engine`, `monitor_engine`, `monitor_plot_baseline_engine` and existing contracts |
| Unchanged chart cadence and resources | Four-walls/mixed animation and modem/speaker competition, original examples, two-tick gate and unchanged budgets |
| Actual appearance/input and peer state agreement | Full-client dense scene and server plus two full clients in each content mode, fresh and cold phases; native input and independently evaluated state snapshots |

Settings paste's missing scale-resize notification was reproduced against the
immutable release before the narrow fix. The changed path uses the existing
resize queue and presentation invalidation; it adds no public method. Marking
and cancelling deconstruction remain distinct from actual removal.

Some older fixtures directly edit private models or status fields. Those edits
now explicitly notify the existing mutation/status boundary; their assertions,
resource ceilings and native outcomes are retained. Actual-tick tests separately
prove that production callers deliver their wakeups. No recurring global scan is
retained solely to detect a test's private mutation.

## Structural acceptance

The baseline counter run fails for real redundant work after the 144-tile scene
settles: topology signature construction and full proofs continue without a
change. Observers are installed before captured backend/authority functions;
visibility assignments and the actual private signature/proof boundaries are
instrumented rather than an unused wrapper.

The candidate requires exactly 144 observation visits per measured tick. In each
settled idle, cold-idle, outage and restored window it requires zero topology
scans, full display proofs, captures, frame/cell/cursor preparation, monitor
native-object creation/retirement and visibility writes. Each window contains
eight actual ticks. One independent writer may capture only its own display;
three unchanged peers retain their exact fronts. The four-writer window must
make real producer progress without stable-topology reconstruction.

Residual observation and selected-path checks are intentional. Fresh calls,
touch and publication still perform their own authority proofs. Silent movement,
rotation and force changes are exercised separately from the same-event probes.
The engine rejects same-body cross-surface combinator teleport; the surface case
uses native cloning and retirement and proves distinct identities, not an
unsupported transfer. Helper-loss recovery restores the owned helper explicitly.

## Timing method and interpretation

All engine processes use the campaign `flock`. Matched comparisons run serially
with identical engine, scene, scale, guest bytes, workloads and settings. Each
case creates its own isolated save, warms for 120 ticks, cold-reloads in another
process, rewarms for 120 ticks and measures exactly 600 scheduler calls. A second
independent set repeats these cold windows. The zero scene has no monitor tiles;
idle has 144 tiles and a stopped producer; one and all have 144 tiles and real
updating producers. Sparse and full-row submission are separate workloads.

The timing tables report mean, median, p95 and maximum milliseconds per entire
scheduler call for each cold window; do not average per-frame reciprocals or
call these client FPS. Fine-grained phase profiles are a separate observer run
with its own allocation/logging overhead. Raw profiler lines and exact sample
inventories are retained. Resource/ownership and publication cadence assertions
are functional gates, not an unapproved numerical speed threshold.

The host is shared: the run records process/load observations and four available
CPU cores. Other agent/editor/system work was present; the campaign lock excludes
other cooperating Factorio cases, not all host contention. Small differences in
the zero-monitor control and tails must not be attributed solely to this change.
The candidate still pays live physical and circuit/path maintenance and active
program/render work. The optimization is not a zero-overhead or full-modpack
performance claim.

The [complete timing distributions and phase summaries](monitor-maintenance-timings.md)
are generated from the verified raw receipts. Each cold window is reported
separately rather than hiding tails inside a pooled average.

## Native-client and connected-peer acceptance

Both licensed full clients and matching data were checked as 2.1.23, not the
historical 2.0.77 installations. All config, write-data, mods and saves are private
to the case; actual logged write paths are checked. The initially misconfigured
pilot is rejected and retained separately, not counted as acceptance.

The peer driver starts a real server and first full client, then joins a second
full client. It compares all three independently evaluated monitor/computer
snapshots, performs non-anchor touches through all cardinal transforms, tests
both players and GUI-focus refusal, native deconstruction marking/cancellation,
coherent repaints, readable save creation, separate-process cold recovery,
actual editor Stop buttons and actual mining. Unaffected fronts survive removal;
completed startup effects do not replay. Each mode has 28 driver checks over two
phases. Clients close normally and the server receives `/quit`; exit receipts
and desync-log/archive checks are separate from state equality.

Dense rendered runs cut and restore a real native power supply without clearing
the models. Captures show the same complete powered fronts, hidden output during
the outage, restoration, native mark overlays, cancellation and the removed tile.
Native window recordings are separate from game screenshots. The visual blink
proof uses an ordinary live client, a focused scale-2 cursor and native hover moved
off the display: samples show the white underline switching on/off with unchanged
glyphs in both modes. Each recording is 8 seconds / 240 frames at 1280×720;
701 settled actual ticks retain fronts with no presentation jobs/work/retirement.
This focused visibility check does not replace the full-density 10584-cell native
scene or peer tests. Overview/benchmark cursor clips were visually inconclusive
and are not counted as blink acceptance.

Xvfb/software rendering validates appearance and input, not representative GPU
throughput. Matching selected snapshots and these localhost peers do not prove
all arbitrary modpacks, network conditions or every transient frame.

## Save compatibility and delivery

See the player guide's [save compatibility and rollback](player/monitor-animation.md#save-compatibility-and-rollback).
Missing old scheduling metadata is enrolled once during synchronized work;
ordinary load neither replays source nor constructs a queue or native objects.
Unknown versions/container shapes remain recoverable and refuse service.
Upgrade tests use a **private metadata-only 0.1.17 copy** to exercise a real
version transition while source stays 0.1.16; internal directory, manifest and
version agree. The original archives remain immutable.

Canonical specification synchronization and archive belong to the downstream
merge/archive card. The current delta/API companion remain authoritative for
this feature; existing canonical lifecycle, inspection and network content is
not replaced wholesale. This implementation does not merge, archive, allocate a
release version or publish a release.
