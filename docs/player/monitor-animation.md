# Bounded 30 Hz monitor animation

The paste-ready program is `examples/smooth-sine-chart.lua`. The connected-line
example ships with 0.1.7, including the runtime/presenter optimizations and the
unchanged fivefold default live budgets introduced in 0.1.6. Older published
archives retain their original example; do not assume their performance matches.

## Connected subpixel line

The chart uses the monitor's existing 2×3 mosaic glyphs (bytes 128–159), rather
than drawing `*` markers. Each character cell carries six square subpixels with
two colors, using the same basic encoding idea as Pixelbox-style renderers. When
the sixth subpixel is foreground, the encoder complements the mask and swaps
foreground/background colors. No additional font, library or rendering API is
required.

Adjacent sine samples are joined with vertical spans, so steep sections do not
leave gaps. The top row remains readable text. The remaining area has twice the
character width and three times the character height in subpixels. A gray
horizontal axis yields to the green curve in cells where they intersect, keeping
each cell within the two-color limit. This is a connected pixel line, not vector
anti-aliasing or a guarantee of smooth real-time motion.

Only occupied curve cells are encoded; there is no dense pixel canvas. Rows are
generated once per grid size and cached with their text **and both color strings**,
so a color inversion cannot be mistaken for an unchanged row. To use it, replace
the editor document with the complete example, then Validate, Save and Run.

## Producer and presentation

The chart samples one phase and updates every selected screen in the same
callback, every two simulation ticks. It generates rows once per distinct grid
size and only resubmits changed rows. A cheap cursor setter participates even
when rounding leaves a screen unchanged. Row caches assume this example is the
writer of the screen content; monitor synchronization itself is not a write lock.

The model tracks actual changed cells, not merely writes or cursor revisions.
In 0.1.7, identical row writes also avoid copying
the complete cell root; a needed copy is admitted before the first changed cell.
Snapshots freeze a bounded copy of the dirty-index set. Publication consumes
only matching changes: later writes and palette/clear epochs remain pending.
Acknowledgement uses a constant-time reset for an unchanged root or a prepaid
dirty-index pass for a stale root, retaining only later, unconsumed damage.

After an initial full image, sparse frames copy prepaid flat reference roots,
prepare only damaged cells and transfer unchanged native-object ownership.
Retirement scans only superseded damaged cells. Full clear, scroll, palette,
geometry and legacy/untracked state use the conservative full preparation path.
The 0.1.7 presenter additionally shares unchanged backgrounds and glyphs
independently. Changed components are still prepared hidden; borrowed components
stay owned by the old front until the admitted publication. Cancellation and
retirement must not destroy borrowed components.
These reference-root copies still cost work proportional to the grid; this is
not an unbounded O(dirty-cells)-only renderer or a general GPU framebuffer.

The 1024 preparation/retirement cell-check allowance, 160000 commit cap, object
limits and retained-cell capacities are unchanged. The maintenance default is
still 200000; its shared allowance is now a live [Map setting](api/limits.md#live-mod-settings).
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
module and runs the production scheduler in Factorio 2.1.23. Layouts are four
6×6 walls at the script's scale 2, or mixed 6×6, 3×6, 3×6 and 1×1 walls, with
cardinal rotations and real red/green wiring. Both base and Space Age are tested.
The real editor performs Validate, Save and Run without resetting same-tick
credits. An independent oracle decodes every plotted subpixel from the actual
glyph/foreground/background cells, checking the connected curve and axis against
the sampled phase. Native front values and visibility are also checked on every
sampled publication.

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
Historical 2.0.77 software-rendered base and Space Age clients displayed the
connected subpixel curves in actual window captures and native screenshots; an
eight-second base-client recording shows the animation. The older screenshot
equality and performance reports used star markers, not this new workload.
These shared-host checks do not establish steady real-time motion.
The 2.1 release is headless-only: rendering, representative GPU-backed FPS and
multiplayer-client smoothness remain unverified on that engine.

The source checkout also includes `tools/monitor_performance.py` for serial,
matched sparse/full-row benchmarks and longer simulated soak runs. It reports
whole-scheduler timings, distinct image changes, retained-object ownership and
cold reload, rather than equating two-tick publication with acceptable CPU cost.
The performance changes ship in 0.1.7, not in the unchanged published 0.1.6 archive.
