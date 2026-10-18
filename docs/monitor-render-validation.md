# Rendered monitor validation — 2026-10-16

Historical workload: these frozen archives, screenshots and timings use the
earlier star-marker example. The later connected-subpixel chart is a different
producer workload and requires its own verification; the original evidence
bundle remains unchanged.

## Verdict

**Rendered functional validation passed; the smooth, low-UPS-cost target is not established.**

All nine final graphical-client cases completed with normal exit, exact measured
tick counts, a running producer and the required two-tick publication cadence.
The three pinned native screenshots are pixel-identical between baseline and
candidate. An actual-window capture and an eight-second recording confirm that
the four rotated monitors display changing charts. No missing backgrounds,
missing glyphs or mixed partial chart images were observed in the inspected
samples. Ordinary circuit/power wires and the mouse pointer remain visible over
parts of the scene; these are not missing monitor content.

These are **software-rendered, shared-host results**, not GPU-backed desktop
performance acceptance. Concurrent CPU-heavy Java processes were observed on
the four-vCPU host. They were not stopped. Consequently, the before/after timing
differences cannot all be attributed to this change, and no clean graphical
speedup claim follows from this matrix. Some raw timings improved; the base
full-row comparison did not show a convincing benefit and its frame cadence was
worse. All results are retained rather than selecting the favorable comparisons.

## Environment and method

- Provided official Linux full clients: Factorio 2.0.77, build 84539, base and
  Space Age. The expansion runs enabled `space-age`, `quality` and
  `elevated-rails`, using the same Nauvis chart scene; they did not test every
  expansion surface or mechanic.
- Private Xvfb display, 1280×720, camera `(16, 2.5)`, zoom `0.95`, requested low
  graphics preset. The actual client reported medium graphics quality, low
  rotation quality, and four rendering threads. No user desktop was targeted.
- Actual renderer: `llvmpipe (LLVM 20.1.2, 256 bits)`, OpenGL 4.5,
  Mesa `25.2.8-0ubuntu0.24.04.2`. Requested VSync was unsupported by this display.
  Even the native CSV's `gpu-frame` field describes a software rendering path.
- Four 6×6 monitor walls, scale 2, cardinal rotations, one producer, unchanged
  production limits. Real native substations and an electrical source supplied
  power. The vanilla intro/crash site were disabled in the test scene.
- Fresh equivalent saves were generated deterministically with seed 1 for each
  archive. These are matching scene constructions, not byte-identical save ZIPs.
  Guest source and test-module hashes match within every comparison pair.
- `--benchmark-graphics`, `--benchmark-ticks`, and `--output-perf-stats` exercised
  actual graphical clients. Production archive entries were checked byte-for-byte
  after test-only fixture injection; no production code was changed for this test.
- `game.speed=1`; the scheduler measurement window starts after 120 warmup ticks.
  The six short timing runs each measure exactly 1,800 further ticks. An extra
  final engine tick during shutdown is not added to the fixed sample window.
- Scheduler figures are elapsed `LuaProfiler` time around the full production
  scheduler, excluding fixture checks/logging outside the call. Observer
  allocations, software rasterization and external contention can still affect
  subsequent samples and wall time.
- Observed UPS is measured ticks divided by elapsed log-timestamp wall time.
  Approximate FPS is `1000 / mean(cpu-frame)` from the native per-frame CSV.
  CSV analysis keeps world frames with at least 2,604 sprites, drops their first
  120 frames, and uses the remaining positive frame durations. This frame window
  is independent of the scheduler's tick warmup. It is not physical-display
  refresh, an FPS-overlay reading, or proof against display tearing.
- Screenshots/video were captured in two separate 600-tick cases, excluded from
  the timing comparison below. The video is encoded at 30 FPS; that encoding
  rate is not a measurement of game FPS.

## Raw short-run results — contention-confounded diagnostics

| Mode / workload | Build | Scheduler mean ms/tick | Scheduler p95 ms | Observed UPS | Approx. FPS | Frame p95 ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Base / changed rows | Baseline | 47.39 | 116.72 | 18.99 | 12.05 | 183.58 |
| Base / changed rows | Candidate | 15.06 | 38.63 | 50.63 | 35.50 | 59.57 |
| Base / every row resubmitted | Baseline | 34.63 | 81.87 | 26.49 | 16.30 | 116.73 |
| Base / every row resubmitted | Candidate | 32.60 | 82.37 | 26.85 | 13.05 | 152.38 |
| Space Age / every row resubmitted | Baseline | 33.45 | 78.60 | 27.36 | 18.11 | 113.91 |
| Space Age / every row resubmitted | Candidate | 16.60 | 42.46 | 49.37 | 34.59 | 60.08 |

All six cases recorded 900 distinct cohort image changes and a maximum
publication gap of two simulation ticks. This does not mean 30 distinct images
per real second when the simulation runs below 60 UPS. The sparse source is the
packaged sine-chart example; the full-row variant changes only its row-submission
predicate in the test copy. **This is not execution of Telem or its full subpixel
plotter.**

## Sustained candidate run

Base mode, full-row submission, with rendering continuously active:

- 18,000 measured ticks: 300 simulated seconds, **408.433 seconds of measured
  wall time**, excluding startup/warmup.
- 9,000 distinct cohort image changes; maximum publication gap two ticks.
- Observed UPS **44.07**, approximate FPS **31.22**, and about **22.04 distinct
  cohort updates per real second**.
- Scheduler mean **18.72 ms**, p95 **49.68 ms**, maximum **317.80 ms**.
- Native frame-time p95 **80.02 ms**, maximum **361.83 ms**. These spikes prevent
  calling this consistently smooth merely because its average is above 30 FPS.
- Thirty periodic resource audits sampled **3,027–3,035** native mod render
  objects. Every sampled object belonged to a retained front, staging, retirement,
  orphan-cleanup or device-status-art root. Cell/object capacity and published
  glyph/visibility checks passed. These are sampled bounds, not continuous
  high-water monitoring or proof of absence of every possible memory leak.
- Whole-client sampled RSS ranged from **1,071.01 to 1,073.75 MiB**. It includes
  the game and software renderer, not just this mod's memory.

Scheduler means in successive 3,600-tick windows were 30.75, 16.24, 14.87,
17.34 and 14.40 ms. The run does not show steadily worsening scheduler cost,
but host-load changes preclude treating this as a controlled aging comparison.

## Correctness and follow-up checks

Pinned screenshots at fixture steps 180, 210 and 240 match baseline/candidate
pixel-for-pixel across the entire image. Candidate images at different steps
are different, confirming actual chart motion rather than repeated static
captures. The actual-window video contains 240 encoded frames over eight
seconds at 1280×720; successive samples were visually inspected.

After all graphical timings finished, the exact candidate archive also passed
`tests.monitor_optimization_contract` in both engine modes and
`tests.monitor_component_contract` with separate-process cold reload in both
modes. This includes the latest identical-write/refused-copy and
cancellation/power-loss assertions that had not been rerun in the earlier
headless report.

Early harness probes are preserved separately and are not counted among the
nine final cases. The first scene was obscured by native electrical warnings
and the vanilla intro. A subsequent fixture assertion incorrectly rejected an
already-connected copper wire, and another counted one extra final benchmark
tick. Those fixture issues were corrected and the full final matrix was rerun;
no production change was needed to fix them.

## Evidence and reproduction

Durable local evidence directory:

`/home/siredvin/artifacts/tweaked-computers/render-validation-2026-10-16`

It contains `animation.mp4`, `rendered-scene.png`, `motion-strip.png`, the pinned
screenshots, raw client logs/CSV, per-case summaries and source hashes,
`matrix.json`, aggregate `results.json`, contract results, original tested mod
archives, and failed-probe evidence. `evidence-manifest.json` records verified
copied-file hashes. Licensed game binaries/assets, caches and display
credentials are not included. All test clients and private displays exited.

Frozen production archive SHA-256s:

- Baseline: `b4300bcb802057221e18ba1964a326b9761149842283bb436413874654370035`
- Candidate: `594669200beea1d5dc0ebf6da70d5549af0de70e2c27209000e73a4242022a18`

Both are development snapshots with `0.1.6` metadata, not new releases. Runtime
code was not changed by this validation; later report/documentation edits are
not represented by those frozen archive hashes. Nothing was committed, pushed
or published as part of this rendered validation.

The retained runner is a host-local reproduction aid, not a supported portable
tool. It uses this checkout's provided clients/config template and requires
Python, Xvfb, X11 libraries and ffmpeg. On this same host, a fresh candidate case
can be run without rebuilding the production archive:

```sh
E=/home/siredvin/artifacts/tweaked-computers/render-validation-2026-10-16
xvfb-run -a -s '-screen 0 1280x720x24 -nolisten tcp' \
  python "$E/render_case.py" \
  --archive "$E/archives/candidate/tweaked-computers_0.1.6.zip" \
  --case candidate-recheck --workload full-blit --ticks 1800
```

Use a fresh `--case` name; existing output directories are rejected. The raw
matrix command ledger retains the original scratch paths as historical evidence.
For another machine, first adapt the runner's repository/engine paths and supply
licensed matching game data.

## Remaining acceptance

A quiet GPU-backed client run with the user's actual save/mod settings and chart
source is still needed to validate representative FPS/UPS and sustained visible
smoothness. Multiplayer, physical-display tearing/VSync and a real factory's
additional workload were not tested here. The prior headless CPU improvements
remain separate evidence; this rendered matrix neither establishes a clean GPU
speedup nor completes the original low-UPS-cost performance goal.
