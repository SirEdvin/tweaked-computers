# Bounded 30 Hz monitor animation

The paste-ready program is `examples/smooth-sine-chart.lua`. It requires version
0.1.6's updated runtime and presenter, including the fivefold default live budgets;
the unchanged published 0.1.5 archive does not include this optimization.

## Producer and presentation

The chart samples one phase and updates every selected screen in the same
callback, every two simulation ticks. It generates rows once per distinct grid
size and only resubmits changed rows. A cheap cursor setter participates even
when rounding leaves a screen unchanged. Row caches assume this example is the
writer of the screen content; monitor synchronization itself is not a write lock.

The model tracks actual changed cells, not merely writes or cursor revisions.
Snapshots freeze a bounded copy of the dirty-index set. Publication consumes
only matching changes: later writes and palette/clear epochs remain pending.
Acknowledgement uses a constant-time reset for an unchanged root or a prepaid
dirty-index pass for a stale root, retaining only later, unconsumed damage.

After an initial full image, sparse frames copy prepaid flat reference roots,
prepare only damaged cells and transfer unchanged native-object ownership.
Retirement scans only superseded damaged cells. Full clear, scroll, palette,
geometry and legacy/untracked state use the conservative full preparation path.
These reference-root copies still cost work proportional to the grid; this is
not an unbounded O(dirty-cells)-only renderer or a general GPU framebuffer.

The 1024 preparation/retirement cell-check allowance, 200000 maintenance budget,
160000 commit cap, object limits and retained-cell capacities are unchanged.
Snapshots remain immutable, old frames remain visible until one fully admitted
publication, and no flush or new guest frame API is required.

## Runtime costs

A private FIFO cache holds at most eight exact-source validated plans, each with
at most 32768 compilation charge records. It retains no AST, factory, environment,
guard or guest closure. Returned plan tables cannot mutate the private copy.
Warm compilation charges exactly the same units as cold parsing; a refused
replay charges the same accepted prefix, including shared-host exhaustion.
Cold processes reconstruct the proof normally without renewing saved credits.

Physical discovery/all-member power proofs may be reused only within one
non-yielding callback. The reviewed monitor provider cannot change physical
connectivity or members. Other providers invalidate those proofs before their
method executes, even when it later throws. Every method still checks its active
run and resolved identity/generation; all original work charges remain in force.
No physical proof survives into a later callback or cold process.

## Verification and limits

`tools/monitor_animation.py` wraps the exact packaged guest bytes in a test-only
module and runs the production scheduler in Factorio 2.0.77. Layouts are four
6×6 walls at the script's scale 2, or mixed 6×6, 3×6, 3×6 and 1×1 walls, with
cardinal rotations and real red/green wiring. Both base and Space Age are tested.
The real editor performs Validate, Save and Run without resetting same-tick
credits. An independent oracle checks complete models, snapshot phases, native
front values and visibility on every sampled publication.

The gate requires 360 actual publication intervals per mode/layout, none above
two simulation ticks, after warmup; it spans the periodic rediscovery. A separate
process checks unchanged saved source/state/presentation/credits before resuming.
The fixture deliberately freezes scheduling while writing its snapshot, so the
artificial paused boundary separates measurement windows. Power loss and recovery
are also exercised. Scheduler CPU samples exclude fixture observation and world
setup but include cold reconstruction; profiles are diagnostics, not CI timing
thresholds or client rendering measurements.

At 60 UPS, a two-tick publication cadence corresponds to 30 updates/second.
A slower simulation, client rendering, very dense grids, unrelated factory work,
other writers and larger numbers of active producers can reduce visible motion.
Graphical-client FPS and multiplayer-client smoothness remain unverified.
