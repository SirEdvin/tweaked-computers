# Maintenance-budget benchmark (MB2)

Measured on 2026-10-19. This is a recommendation, **not a production-default change**.
The current default remains `maintenance_work_per_tick = 200000`.

## Recommendation

**Raise the provisional default to 300000 in a separately approved change.**
It is the smallest **tested** candidate that completed the combined moderate
workload in both base and Space Age. Keep the total host ceiling at 5000000 and
all renderer, guest and resource caps unchanged. This is a capacity recommendation,
not a speedup, smooth-animation promise, or proof that 300000 is the mathematical
minimum.

- Retaining 200000 is reasonable for the tested light/small, single-colour factory,
  but not a satisfactory general default for the tested two-colour Space Age
  scene: one shared Logic Handler and four computers repeatedly faulted with
  `E_BUSY` before sustained useful work began. This is not a saturation campaign.
- 300000 ran that scene with peak maintenance spending 258224, leaving 41776
  logical units of measured total-maintenance margin. It takes 100000 units from
  guest headroom: 4800000 becomes 4700000, a 2.0833% reduction relative to the old
  guest allowance. These workloads did not approach either guest ceiling.
- 400000 produced **no additional useful callbacks, input observations or monitor
  publications** over 300000. Its guest headroom is only 4600000. There is no
  measured reason here to pay that additional reservation for the default.
- A higher maintenance ceiling does **not** fix the monitor-heavy CPU tails.
  At 300000, the moderate workload's profiled scheduler mean was 15.155 ms base /
  15.818 ms Space Age, with pooled p95 32.922 / 35.541 ms. The low-instrumentation
  controls remained similarly expensive. Do not market this as sustained 60 UPS,
  30 FPS, or native-client input responsiveness.

Scope warning: the measured windows used the existing 60000 render reservation;
none requested a 160000 boosted reservation. 300000 therefore is **not** evidence
that all maximum atomic render/topology combinations coexist with this sampler.
A boosted tick leaves only 140000 non-render units, below this Space Age scene's
measured non-render mean of about 187958. The existing boost fairness policy and
safety caps are not changed or certified for that combination by this report.

## Source, engines and evidence

Dependency consumed by a real merge, without dropping current main behavior:

- Main base: `4fe09733d5a30fa5bbf4ad08af71ae9fa60bc941`.
- Verified MB1: `bf769d71a88d20f4258cf2f03d36cd8a5a6b8ef1` (PR #15, unmerged when tested).
- Local prerequisite merge: `2aff70a`.
- Frozen benchmark source/harness head: `ae82427b703427046a962ae8e34b3e091ae58f47`.
- Frozen built candidate archive SHA-256:
  `11c09612fe07d92a2f5b5e44894bf9b2a066c874a8b659eaaee94b28aa3b2ffb`.
- Engine: official headless Factorio **2.0.77, build 84539**, linux64. Base and
  Space Age + quality + elevated-rails were tested separately. Executable SHA-256:
  `c9ac91d318bdbcce5afaac30d48f4b71dc38af257712a5d4d4c4feb625737198`.

Durable evidence root (outside git; historical attempts are not overwritten):

```text
/home/siredvin/artifacts/tweaked-computers/mb2-maintenance-2026-10-19-H5PXQF/
  accepted-build.json
  accepted/package/tweaked-computers_0.1.9.zip
  accepted/profiled/{environment.json,summary.json,<case>/...}
  accepted/control/{environment.json,summary.json,<case>/...}
  accepted/summary-final/{aggregate.json,overview.csv}
  accepted/correctness/{runtime_budget_engine,monitor_budget_engine,integration_engine}/
  accepted/summary-tests.log
```

Each case retains `provenance.json`, `contention.json`, `result.json`, `runner.log`,
engine/create logs, the actual injected test ZIP, commands, the cold snapshot and
both shutdown receipts. `result.json` contains raw counted per-tick observations
and per-phase timing arrays; engine logs are the original profiler diagnostics.
`environment.json` records exact commands, source head/status, runner hash, engine
hash/version, UTC start, Python and hardware. The report/aggregation tools added
later do not change the frozen benchmark observer or tested runtime.

`tools/maintenance_benchmark.py` reuses `tools/smoke.py`, replacing the opt-in
animation fixture with `tests/maintenance_benchmark_engine.lua`. It adds a
control-parsing import to install a forwarding observer **before** production
hook registration. No scheduler, sampler, renderer, service, prototype or settings
implementation bytes are replaced. The external per-case provenance inventories
all unchanged payload hashes and all test-only overrides. The copied candidate's
internal package manifest describes the original candidate, not those test-only
overrides; use external `provenance.json` for the injected ZIP.

The summary verifies one candidate hash, one source head, one observer/driver
payload and identical other effective limits across all 72 cases. Candidate
settings and the test-only `profile` switch are explicit. ZIP metadata/configs
can differ; unchanged production **payload bytes**, not whole test-ZIP hashes,
are the paired-source invariant.

No SC3 worktree files were imported. In particular, SC3's sequential factory /
renderer evidence is not presented as combined benchmarking here.

## Machine and measurement limits

KVM guest advertising AMD Ryzen 9 7900; **4 online vCPUs**, one thread per exposed
core; Linux 6.8.0-142-generic x86_64 / glibc 2.39. The initial memory check reported
31 GiB RAM, no swap. Python 3.14.7. Full `lscpu` output is retained. This is not a
dedicated physical-core, pinned-frequency or representative player-GPU machine.

All cases were serial, including controls; no correctness suites, media work or
other benchmark jobs were intentionally run alongside the timing matrix. Other
host/VM activity was not prohibited or fully attributable. A 1-second observer
retained `/proc/stat`, CPU pressure and load average over **whole cases**, including
startup, save and shutdown, not just the profiled scheduler window:

| Host observation | Count | Mean | p95 | Maximum |
| --- | ---: | ---: | ---: | ---: |
| Busy %, all four vCPUs | 604 intervals | 24.955 | 32.316 | 50.505 |
| Steal % | 604 intervals | 0.0096 | 0 | 0.256 |
| I/O wait % | 604 intervals | 0.137 | 0.508 | 1.250 |
| One-minute load | 676 records | 1.006 | 1.211 | 1.297 |
| CPU pressure `some avg10` % | 676 records | 0.405 | 0.890 | 1.130 |

These counters include the experiment itself. They do not prove a contention-free
host or identify the cause of an individual tail. Small CPU differences between
passing budget candidates are not causal speedup evidence.

Times below are Factorio `LuaProfiler`-reported elapsed scheduler/phase durations,
labelled CPU diagnostics, **not** OS thread CPU accounting. Profiler objects are
ephemeral and never saved or used for decisions. Hook wrappers forward real
production functions, preserve return arity and rethrow original errors. Timers /
dispatch are summed per actual tick; absent timer calls on faulted runs contribute
explicit zero-call work, not invented profiler measurements.

Total scheduler timing excludes fixture setup/input mutation, JSON/log emission,
state/readback/image observers, periodic audits and persistence. It includes
production lifecycle, sampling, notifications, timers, guest dispatch and native
render-object operations. Phase-wrapper overhead is inside the scheduler profile.
Observer allocations can cause later GC inside a timed call. Low-instrumentation
controls remove phase profilers/wrappers but retain the same workload, observations,
whole-scheduler profiler and refusal counter. They are not observer-free engine
benchmarks.

## Candidates and held settings

[MB1's supported setting contract](maintenance-budget-setting.md) permits requests
200000–100000000 and clips effective maintenance to `host - 1`. **199999 and all
lower requested values were not executed**: they are outside the supported
prototype range. This is a conservative supported floor, not measured proof that
every lower value fails, and not a newly discovered Factorio engine minimum.
Do not bypass validation or reduce rendering to manufacture a lower comparison.

The existing render baseline is 60000, adaptive maximum / whole-commit limit
160000. 200000 originally leaves 140000 non-render baseline opportunity, or 40000
on boosted ticks. Candidate spacing uses the actual 100000 baseline-to-boost
reservation difference:

| Maintenance request/effective | Baseline non-render headroom | Boosted non-render headroom | Guest headroom |
| ---: | ---: | ---: | ---: |
| 200000 | 140000 | 40000 | 4800000 |
| 300000 | 240000 | 140000 | 4700000 |
| 400000 | 340000 | 240000 | 4600000 |

300000 restores the old baseline non-render opportunity even on boosted ticks;
400000 probes one additional such step. These are accounting opportunities, not
reservations guaranteed independently to every phase. No render/object/cell or
atomic topology cap increases with them. The 160000 atomic render ceiling itself
precludes claiming arbitrary very small maintenance values are feasible.

All other runtime settings remain at shipped defaults, especially host=5000000,
compile=1250000, callback work=500000 and callback allocations=81920. Complete
limit readbacks are in every case's `configuration`. The maintenance value is
written using real `LuaSettings` in the owning mod and refreshed through the
registered production handler. This verifies runtime integration, not native
settings-GUI event delivery.

## Workloads and windows

Map seed 1, cleared bounded landfill work area; real built device bodies and owned
children; a fixed 100 MW native electric-energy interface, substations and real
wires. No synthetic per-tick energy refill, repeated same-tick scheduler loop,
manual ledger reset, synthetic clock or larger host ceiling is used. The native
scene runs at `game.speed=100` to bound wall time; it is not a UPS measurement.

| Workload | Active computers | Native circuits / useful guest work | Monitor footprint |
| --- | ---: | --- | --- |
| `idle` (light control) | 1 | Counter callback every 60 ticks | None |
| `mixed` (small factory control cell) | 2 | One shared Logic Handler, two red-input subscriptions; changing native stock signal every 30 ticks; output bank drives a wired lamp; shared KV telemetry; dashboard callbacks every 6 ticks | 2×2 plus 1×1 tiles; 5 tiles, 320 character cells |
| `heavy` (moderate monitor-heavy) | 4 | Same one shared handler, four subscriptions alternating red/green native inputs; stock changes every 30 ticks; native output/lamp and KV work continue; complete monitor blits every 2 ticks | Four 3×3 walls; 36 tiles, 2480 character cells |

This small native circuit-control cell has no item-throughput claim. Its stock
signal is deliberately controlled by the fixture; it is not an ore/assembler
production model. Actual inserter transfer remains covered separately by the
unchanged integration correctness fixture. All listed guest/circuit/monitor work
runs **together** during the measured window, not as independent success phases.
The monitor-heavy case is below the physical/cell/computer ceilings, not compulsory
simultaneous saturation of any capacity inventory.

Production topology/power runs for at least 120 setup ticks, programs activate
through actual editor-model Validate → Save → Run (explicit table-backed player
authority, no native GUI), then 120 warmup ticks. The fixture freezes after requesting
a real save, verifies identities/content/credits on cold load in a separate server,
rewarms for 120 ticks, measures **exactly 600 actual ticks**, stops the programs and
waits for paid retirement/output cleanup before the completion marker. Save-boundary
pauses are outside the window. Original commands and actual begin ticks are retained.

Three fresh cold experiments per mode/workload/budget were profiled. Repetition 2
reversed candidate order to reduce monotonic order bias. Each configuration also
has one fresh 600-tick low-instrumentation control, run serially after the profiled
matrix. There is no claim of independent randomized sampling or confidence bounds.

Counts verified from files, not inferred from attempted commands:

- 18 configurations × 3 profiled repetitions = **54 cases / 32400 ticks**.
- 18 low-instrumentation controls = **18 cases / 10800 ticks**.
- Total **72 cases / 43200 ticks**, each with map creation and two cold phases.
- **144/144** cold phases: normal acknowledged `/quit`, exit zero, no signals,
  no forced cleanup. All 72 cases passed structural completion/persistence checks.
- **Four useful-work failures**, retained: Space Age/heavy/200000 in all three
  profiled repetitions and its control. Their smoke subprocesses exited zero;
  both matrix drivers correctly exited **1 for the failed functional gate**, not
  because the engine crashed. Do not interpret `accepted/` as every baseline passing.

## Scheduler timings

Each profiled row pools **1800 samples**; p95 is nearest-rank, not an average of
per-run p95s. Control mean has 600 samples. Durations are milliseconds. The failed
Space Age/200000 heavy row measures the cost of already-stopped programs and is
**not** a faster successful factory.

| Mode | Workload | Budget | Mean | Median | p95 | Max | Control mean | Useful pass/repetitions |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Base | idle | 200000 | 0.122 | 0.107 | 0.191 | 0.862 | 0.099 | 3/3 |
| Base | idle | 300000 | 0.141 | 0.116 | 0.228 | 3.492 | 0.099 | 3/3 |
| Base | idle | 400000 | 0.146 | 0.117 | 0.219 | 3.223 | 0.099 | 3/3 |
| Base | mixed | 200000 | 1.342 | 0.852 | 3.304 | 9.398 | 1.339 | 3/3 |
| Base | mixed | 300000 | 1.349 | 0.853 | 3.237 | 7.334 | 1.327 | 3/3 |
| Base | mixed | 400000 | 1.371 | 0.874 | 3.493 | 7.964 | 1.269 | 3/3 |
| Base | heavy | 200000 | 15.508 | 12.533 | 34.002 | 55.652 | 15.153 | 3/3 |
| Base | heavy | 300000 | 15.155 | 12.377 | 32.922 | 43.744 | 15.428 | 3/3 |
| Base | heavy | 400000 | 15.416 | 12.587 | 33.705 | 48.907 | 15.457 | 3/3 |
| Space Age | idle | 200000 | 0.129 | 0.112 | 0.214 | 1.061 | 0.101 | 3/3 |
| Space Age | idle | 300000 | 0.126 | 0.110 | 0.202 | 1.053 | 0.099 | 3/3 |
| Space Age | idle | 400000 | 0.130 | 0.111 | 0.216 | 1.218 | 0.107 | 3/3 |
| Space Age | mixed | 200000 | 1.516 | 0.911 | 4.007 | 16.889 | 1.358 | 3/3 |
| Space Age | mixed | 300000 | 1.456 | 0.895 | 3.740 | 10.176 | 1.409 | 3/3 |
| Space Age | mixed | 400000 | 1.447 | 0.898 | 3.600 | 9.221 | 1.392 | 3/3 |
| Space Age | heavy | 200000 | 1.553 | 1.193 | 4.153 | 7.728 | 1.538 | **0/3 — stopped** |
| Space Age | heavy | 300000 | 15.818 | 12.730 | 35.541 | 45.743 | 15.515 | 3/3 |
| Space Age | heavy | 400000 | 15.960 | 12.897 | 36.070 | 48.011 | 16.126 | 3/3 |

### Phase diagnosis, 300000 moderate load

Each phase column also has 1800 per-tick observations. Mean and p95 shown; complete
mean/median/p95/min/max arrays for **all 18 configurations** are retained in the
aggregate and per-case results. Timer and dispatch rows sum the four real computers;
phase p95s are not additive and maxima need not coincide.

| Phase | Base mean / p95 ms | Space Age mean / p95 ms |
| --- | ---: | ---: |
| Power-loss lifecycle | 0.278 / 0.530 | 0.282 / 0.502 |
| Clone reconciliation | 0.001 / 0.002 | 0.001 / 0.002 |
| Output authority | 0.042 / 0.061 | 0.041 / 0.061 |
| Monitor grouping | 0.536 / 1.478 | 0.566 / 1.623 |
| Physical-device lifecycle | 0.401 / 0.846 | 0.412 / 0.781 |
| Logic sampling | 1.060 / 2.496 | 1.077 / 2.341 |
| Monitor notifications | 0.003 / 0.004 | 0.003 / 0.004 |
| Peripheral topology notifications | 0.397 / 0.728 | 0.408 / 0.756 |
| Timer advancement | 0.040 / 0.079 | 0.044 / 0.078 |
| Guest dispatch | 4.804 / 12.706 | 4.979 / 13.571 |
| Device status art | 0.078 / 0.103 | 0.079 / 0.103 |
| KV reclamation | 0.013 / 0.016 | 0.014 / 0.016 |
| Native monitor presentation | 7.407 / 19.895 | 7.820 / 21.747 |
| Editor idle maintenance | 0.003 / 0.003 | 0.002 / 0.003 |

The large monitor/native-render and guest costs remain at both higher allowances.
That is an observation, not authorization to redesign those systems here.

## Work, progress, fairness and latency

All 200000/300000/400000 passing runs of a workload produced the same useful work,
model/input observations and publication schedule. Guest peak logical work was
4667 idle, 68705 mixed and 218853 heavy. That is nowhere near even the smallest
4600000 guest reservation; the experiment cannot quantify near-host-ceiling guest
starvation caused by reallocating headroom.

| Mode/workload | Mean / peak maintenance at 300000 | Useful callbacks per 600 ticks | Circuit callbacks per 600 ticks | Publications per 600 ticks | Max publication gap | Stop/retirement ticks |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Either idle | 50884 / 51050 | 10 | 0 | 0 | n/a | 1 |
| Base mixed | 70080 / 73764 | 200 | 40 | 200 | 6 | 1 |
| Space Age mixed | 117696 / 121380 | 200 | 40 | 200 | 6 | 1 |
| Base heavy | 138064 / 162992 | 1200 | 80 | 497 | 8 | 8 |
| Space Age heavy | 233296 / 258224 | 1200 | 80 | 497 | 8 | 8 |

The Space Age/heavy/200000 failed runs instead have **zero sustained useful
callbacks, zero input acknowledgements and zero publications**. Low measured
maintenance after that failure (peak 55207) means subscriptions have already been
removed, not that 200000 was sufficient.

At 300000 the moderate scene's render hooks averaged 45338 maintenance units/tick;
non-render work including scheduler entry averaged 92726 base / 187958 Space Age.
Space Age logic sampling alone averaged 125623, peak 133611. The installed
prototype×quality envelope is 1320 base / 7272 Space Age. Production charges
`universe * 8 + 64 * 16 + 16` for **each requested input colour**, before bounded
native signal readback; this explains much of the accounting difference. It is
not evidence that Space Age's native read itself consumes proportionally more CPU.
No sampler accounting was removed to improve the result.

There were **zero measured-window maintenance refusals** in all 72 windows, but
that alone is misleading: first-phase pressure must also be counted. Across the
profiled matrix, base/heavy/200000 has three setup deferrals (one per repetition),
and Space Age/heavy/200000 has nine first-phase refusals, including the two
sampling-failure ticks per repetition. Controls add one and three respectively:
**16 first-phase refusal observations total**. Only Space Age/heavy/200000 faults
programs: four `E_BUSY` faults per experiment, **16 computer faults total** across
its three repetitions and control, at activation/warmup ticks 124 and 126. No
other final-matrix configuration faults. Both higher candidates retain simultaneous
non-render progress, real input observations and paid monitor cleanup rather than
buying renderer progress by starving guest/control work.

Input latency is specifically **fixture mutation of the real native constant
signal before scheduler entry → guest state acknowledging that value**, not a
keyboard/GUI/network latency. At 300000, all 120 mixed and 240 heavy acknowledgements
across three repetitions in each mode occurred in the same actual tick (0 ticks).
The output wire was read back through the real lamp connection; each passing
600-tick run records its initial value plus 20 signal changes. Final audits match
it to the controlling computer's observed stock. No physical lamp illumination
screenshot is claimed.

Across three repetitions per mode at 300000:

- Mixed: 600 publications, **363 changed-or-initial first-row observations**, gap exactly 6 ticks,
  snapshot-seal-to-publication latency 0 ticks. Small displays can clip counters;
  a publication is not necessarily a changed picture.
- Heavy: 1491 publications, **1491 changed-or-initial first-row observations**, gaps 4–8 ticks,
  median 5 / p95 7; seal-to-publication latency 3–8 ticks, median 4 / p95 7.
  Producers still execute every two ticks; published frames are coalesced, not a
  two-tick presentation guarantee. Both staging and retirement peak at 2480 cells.
- Programs stop, outputs lose ownership and pending retired jobs drain in 1 tick
  mixed / 8 ticks heavy. Front monitor images deliberately remain as display data;
  this cleanup metric is not destruction of every native render object.

The image counter includes each display's first observed publication as its initial
image: 6 such observations mixed / 12 heavy across three repetitions. Excluding
those gives 357 mixed / 1479 heavy actual first-row changes between measured
publications. It does not count globally unique images; heavy numeric images can
recur later.

These are headless publication/model results. Logical units are neither Lua
instructions nor milliseconds; publication gaps are not graphical FPS.

### Low-instrumentation comparison and retained clock discrepancy

All 12 mixed/heavy configuration groups have exact matches of the complete counted
work/input/output/publication/final-state traces across repeats and controls.
The six idle groups **do not** match absolute begin ticks: profiled/control starts
span ticks 364–367, while each window still contains exactly 600 ticks. The native
cold/start phase source of that small variation was not investigated here.

The initial strict aggregation failed this comparison; it is retained under
`accepted/summary/`. Post-analysis idle checks explicitly retain the mismatch and
verify: shared **actual-tick** observations agree after removing only the local
sample index, begin counter values/progress/final state agree, and full-window
maintenance/guest/resource/refusal multisets agree. No ticks are relabelled, no
results regenerated and no observer rerun is silently substituted. The later
summary reports `all_controls_match=false`, `strictly_matched_groups=12`, and
`all_controls_work_equivalent=true`. This bounded idle comparison is a disclosed
post-analysis rule, with negative regressions for altered work/state/progress.

## Correctness, persistence and exclusions

The combined fixture verifies retained record/state/source/queue/timer/subscription
aliases and sorted content, presentation identity, saved maintenance/guest credits,
non-default setting readback and no startup replay across independent cold engine
processes. It audits native front cells/objects and bounded staging/retirement,
real KV telemetry and output wire values. It does not execute guest work on load.
Every accepted experiment uses normal acknowledged server shutdown, including
functional-failure experiments; no forced cleanup is promoted to acceptance.

Unchanged focused suites also passed on the frozen archive in **both modes**:

- `tests.runtime_budget_engine`: actual settings refresh, spent-credit / non-default
  cold reload, shared headroom and later real-tick recovery.
- `tests.monitor_budget_engine`: existing atomic renderer reservation/fairness,
  same-tick refusal and persisted credits. This is a focused compatibility witness,
  not a combined moderate scene on boosted ticks.
- `tests.integration_engine`: powered real factory wiring, inserter transfer,
  shared/private KV, monitors, source editing and separate-process persistence.

Those are **six suite/mode cases and 12 further clean cold phases**, separately
retained under `accepted/correctness/`; they are not added to timing sample counts.
The build/resource tests and six host-only summary regressions passed as well.

Preserved non-final attempts/exclusions:

| Pilot directory | Cases | Counted ticks (60/case) | Functional failures | Structural failures |
| --- | ---: | ---: | --- | --- |
| `pilot/` | 3 | 180 | Base mixed/heavy, both 200000 (`E_UNPOWERED`) | None |
| `pilot-powered/` | 12 | 720 | Space Age heavy, 200000 (`E_BUSY`) | None |
| `pilot-audited/` | 12 | 720 | Space Age heavy, 200000 (`E_BUSY`) | Same case (parser's missing timer-call category) |
| `pilot-final/` | 2 | 120 | Space Age heavy, 200000 (`E_BUSY`) | None |

- `pilot/`: initial 60-tick fixture had incomplete substation coverage. Idle passed;
  mixed/heavy faulted `E_UNPOWERED`. Those CPU samples are invalid for the intended
  powered comparison, not evidence against 200000. Added actual native power
  coverage; did not inject per-tick energy or alter production power checks.
- `pilot-powered/`, `pilot-audited/`, `pilot-final/`: bounded harness development,
  including the same Space Age sampling failure. The audited pilot initially
  classified the faulted case structurally incomplete because no timer function
  was called after faults. The final parser explicitly represents zero calls and
  still fails useful-work acceptance. Observer changes preceded the final freeze;
  both sides of the final matrix use the same frozen observer.
- `accepted/summary/` and `summary-counted/`: intermediate postprocessing, retained
  alongside the final counted summary; only `summary-final/` supplies tables above.
- No below-supported-range execution, maximum-world saturation, graphical/GPU
  benchmark, connected multiplayer, keyboard echo, or dynamic settings-GUI delivery
  is included. No failed correctness result was repaired by enlarging a cap.

A separate diagnostic ownership defect became visible in the failure results:
shared sampler errors can retain a neighbour's `diagnostic.run_id`, although each
computer correctly faults/cleans up. Counts use authoritative computer IDs, not
that diagnostic field. Source trace: the shared `samples[name].failure` in
`scripts/services/logic.lua` is passed to `runtime.fault`, which mutates caller-owned
`source_revision`/`run_id`. Follow-up card **t_25b8440f** owns that fix; this report
neither changes sampling nor conceals its original diagnostics.

## Reproduce

Use an isolated checkout of the benchmark/harness source, the pinned engine, and
fresh output directories outside git. Runtime defaults and the total host ceiling
must not be edited. Runs are deliberately serial; exit 1 from the two matrix
commands is expected for the retained Space Age/heavy/200000 functional failure.

```sh
HEADLESS=/home/siredvin/tools/factorio/bin/x64/factorio
WORK=$(mktemp -d /home/siredvin/artifacts/tweaked-computers/mb2-repeat-XXXXXX)
python tools/build.py --output "$WORK/package" > "$WORK/build.json"
ARCHIVE=$(jq -er .path "$WORK/build.json")
python tools/maintenance_benchmark.py --factorio "$HEADLESS" --archive "$ARCHIVE" \
  --output "$WORK/profiled" --repetitions 3 --ticks 600
# Inspect the retained summary, then run the independent low-instrumentation side.
python tools/maintenance_benchmark.py --factorio "$HEADLESS" --archive "$ARCHIVE" \
  --output "$WORK/control" --repetitions 1 --ticks 600 --unprofiled
python tools/test_maintenance_benchmark.py
python tools/maintenance_benchmark_summary.py --profiled "$WORK/profiled" \
  --control "$WORK/control" --output "$WORK/summary"
for fixture in runtime_budget_engine monitor_budget_engine integration_engine; do
  python tools/smoke.py --factorio "$HEADLESS" --archive "$ARCHIVE" \
    --output "$WORK/$fixture" --mode both --fixture "tests.$fixture" \
    --production-context --cold
done
```

For the exact historical ZIP, use `accepted/package/` above instead of rebuilding
from later report-only commits. Newly built documentation changes an archive hash;
do not attribute the frozen archive's hash to a rebuilt ZIP. The later delivery
handoff records final source/archive hashes and payload equality separately.

## Remaining decisions

1. Obtain explicit approval before changing the production default to 300000.
2. Treat monitor-heavy CPU/GC/native-presentation costs as a separate performance
   problem; raising maintenance did not improve publication cadence here.
3. Before promising larger/boosted cohorts alongside two-colour Space Age sampling,
   measure that combined reservation balance and real native-client behavior under
   unchanged quotas. This report neither requires a maximum-world campaign nor
   broadens its recommendation into that guarantee.
4. Retain the missing near-guest-ceiling and connected-client evidence as uncertainty,
   not a reason to raise the shared host ceiling or declare all capacities usable
   simultaneously.
