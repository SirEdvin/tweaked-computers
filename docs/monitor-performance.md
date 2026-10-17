# Monitor performance investigation

## Scope and result

The timing tables in this investigation use the earlier star-marker chart and
its recorded source hashes. The newer connected-subpixel example changes the
producer workload; these numbers must not be presented as its measurements.

This change reduces actual scheduler work rather than increasing the runtime,
maintenance, cell, or native-object budgets. It preserves the old visible image
until a fully admitted publication and preserves save/load state.

Four 6×6 monitor walls, scale 2, one producer updating every two ticks:

| Workload | Before mean | After mean | Before p95 | After p95 |
| --- | ---: | ---: | ---: | ---: |
| Sparse changed-row chart | 18.24 ms/tick | 9.52 ms/tick | 42.55 ms | 23.49 ms |
| Same chart, every row submitted | 21.11 ms/tick | 11.68 ms/tick | 49.03 ms | 27.66 ms |

These are serial, 3,600-tick runs on the same Linux KVM host (4 vCPUs exposed
from a Ryzen 9 7900), official Factorio 2.0.77 headless, base mode. They measure
elapsed `LuaProfiler` time around the entire production scheduler, including
physical lifecycle, networks, guest execution, rendering and any garbage
collection occurring inside the call. They exclude world construction, fixture
power injection, assertions and logging. Observer work can still influence later
GC; these are not isolated hardware CPU-cycle measurements. Absolute timings
are host-dependent, not CI thresholds.

The changes are substantial but **not a completed low-UPS-cost guarantee**.
Both p95 values still exceed a 60-UPS tick's time allowance before unrelated
factory work. Two-tick publication does not prove 30 real frames/second.

A subsequent [rendered-client validation](monitor-render-validation.md) exercised
the provided full 2.0.77 base/Space Age clients, pixel comparisons and a sustained
graphical run. Functional checks passed, but software rendering and unrelated
host CPU contention prevent a clean graphical performance claim.

## Bottlenecks and changes

1. **Repeated native physical proofs.** The same monitor members were inspected
   again for front visibility, lane qualification and commit. A render pass now
   reuses positive all-member proofs only inside that one non-yielding call.
   Per-callback computer endpoint proofs have the same narrow lifetime and are
   invalidated before a non-monitor provider executes, including throwing calls.
   Identity/run checks and all original admission charges remain in place.

2. **Redundant entity reads.** Position reads materialize coordinate tables.
   Helpers now fetch coordinates once per check and avoid re-reading a body as
   its own NETWORK endpoint. Availability reuses the position/direction/scope
   facts just established by the complete connector proof, rather than proving
   them twice. The physical loss scan still checks every registered device on
   each tick; it is not replaced with a potentially stale multi-tick cache.
   Green-connector existence is checked immediately after proving the same
   endpoint via red, without repeating its entire ownership/geometry walk.

3. **Expensive accounting of an already-cached network traversal.** Cached
   discovery formerly called the admission machinery once per historical charge
   on every monitor method. The fitting fast path now reserves the trace total
   once. Refusal replays the exact accepted prefix, preserving both per-computer
   and shared ceilings and uncatchable sandbox budget exhaustion.

4. **Sprite churn at cell granularity.** Changing a glyph used to recreate its
   unchanged background; changing a background recreated an unchanged glyph.
   Staging can now borrow each unchanged component independently. Changed
   components are still prepared hidden. Commit prepays the full existing
   worst-case bound, validates handles and transfers ownership only at publication.
   Cancelled staging destroys only its own objects. Retiring an old front cannot
   destroy components transferred to its successor. Immutable cell/palette records
   are shared rather than copied into equivalent metadata triples.

5. **Copying a whole grid for identical row writes.** The terminal model now
   delays its copy-on-write root allocation until the first actual cell change.
   Validation/comparison is still charged. A required root copy is separately
   admitted before the first mutation; identical writes do not pay for a copy
   which never happens. Snapshot immutability and cursor semantics are retained.

The source compiler, sandbox language and safety ceilings are unchanged.
Experiments with native factory caching and guest table-cardinality caching were
removed: the measured improvement did not justify their extra state/trust surface.

## Relationship to Telem

Inspected upstream `cyberbit/telem` at commit
`930cb44d9a20d5f8b47ee39b7fc615169d2a6d2a`. Its Plotter renderer packs a
2×3 subpixel canvas into terminal glyph/foreground/background rows and submits
those rows with `setCursorPos`/`blit`. Its chart adapter composes through a hidden
window before revealing it. Relevant upstream files are
`src/telem/vendor/plotter.lua` and
`src/telem/lib/output/plotter/ChartLineOutputAdapter.lua`.

The full-row benchmark exercises that submission pattern using this mod's
existing chart producer. It is **not execution of Telem**, a complete subpixel
chart workload, or proof of CC:Tweaked runtime compatibility. This mod's
restricted named-handler runtime does not provide the full CC module/window/OS
and object model expected by that library. Original example bytes are preserved;
the full-row variant exists only in the isolated test archive.

## Reproduce

Build outside the checkout, then run baseline and candidate **serially**, with
identical engine, layout, workload, producer bytes and budgets:

```sh
python tools/build.py --output /path/outside/checkout/candidate
python tools/monitor_performance.py \
  --factorio /path/to/factorio/bin/x64/factorio \
  --archive /path/outside/checkout/candidate/tweaked-computers_0.1.6.zip \
  --output /fresh/path/outside/checkout/benchmark \
  --mode base --layout four-walls --workload full-blit \
  --ticks 36000 --deadline 750 --max-gap 2
```

`--mode both` also runs Space Age. `--layout mixed` tests differently sized and
rotated displays. `--workload sparse` uses the exact packaged example;
`full-blit` changes only the row-submission predicate in the test copy. The
benchmark records all inserted/replaced test modules, guest bytes and production
archive SHA-256s in `provenance.json`. Production modules are never patched by
this wrapper. Fresh output directories prevent stale results being mistaken for
new passes.

The harness performs real editor Validate → Save → Run, saves, starts a separate
engine process, verifies retained identities/credits, warms up again, then
measures the requested number of actual scheduler ticks. Acceleration is a
fixture-only `game.speed=100`; simulation duration is not real elapsed time or
client FPS. Default deadlines remain unchanged for other smoke fixtures.

It separately counts publication and distinct visible-content changes. Warmup
fronts are excluded from publication counts. Every 600 measured ticks, it checks
cell/frame/object capacity and inventories every native object against retained
front/staging/retirement/device-art roots, detecting unowned object leaks.
`peak_objects` is the peak of these sampled audits, not a continuous high-water
measurement. Complete native cell-value/visibility audits run outside timed
scheduler calls. The independent image oracle remains in the ordinary animation
correctness fixture.

`summary.json` reports failure if engine execution, cold shutdown, completion
markers or exact sample counts fail. It reports timing rather than claiming
host-independent timing acceptance.

## Validation boundary and required client environment

The installed official headless engine is sufficient for native render-object
lifecycle, quota, actual-tick timing, save/reload and sustained-load tests. A paid
client copy is not needed for those tests.

The complete licensed base and Space Age clients have now been supplied and
exercised through a private Xvfb display. The active renderer was llvmpipe, not a
hardware-backed GPU. To validate representative visible smoothness, tearing,
GPU/FPS cost and the reported real-world stall, the remaining inputs are:

- A copy of the affected save, its mod list/settings and exact chart source.
- The user's actual Factorio version and expansion combination; current automated
  evidence is specifically 2.0.77, not an untested later engine.
- A quiet GPU-backed desktop session or suitable GPU access on this host, with
  the actual hardware renderer verified in the client log. The supplied game
  installations are sufficient; another game copy is not the missing input.
- Alternatively, a user-run client check/recording with FPS/UPS and script-time
  diagnostics visible, plus monitor dimensions, scale, number of active producers
  and desired refresh rate. Use a copy of the save and compare identical camera
  position/zoom before and after.

A copy of the binary alone does not establish a usable graphical environment.
The next architectural target, if this still exceeds the desired budget, is the
remaining physical polling and sandbox/service-call overhead—not larger budgets
or another claim based only on publication cadence. Choosing a trusted/batched
chart API or a different rendering backend would be a separate design change,
not something silently substituted for the current terminal contract.
