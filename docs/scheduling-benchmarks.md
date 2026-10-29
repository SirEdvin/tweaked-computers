# Granular scheduling benchmarks

`tools/scheduling_benchmark.py` establishes the baseline before
`demand-driven-device-scheduling`. It changes no production scheduler, quotas or
player data. It accepts exact built ZIPs, creates isolated scenes and writes a
standalone `report.md` with YAML frontmatter suitable for filing in LLM-Wiki.
It does not modify the wiki, indexes or OpenSpec implementation checklists.

## Run

Use the pinned **Factorio 2.1.23** engines; the runner checks versions and help.
Python's standard library is sufficient. Native UI cases additionally require
licensed full clients, `xvfb-run` and X11. No engine distribution is copied into
the report or committed.

```sh
WORK=$(mktemp -d "${TMPDIR:?}/tc-scheduling-XXXXXX")
python3 tools/build.py --output "$WORK/package" > "$WORK/build.json"
ARCHIVE=$(jq -er .path "$WORK/build.json")
python3 tools/scheduling_benchmark.py \
  --factorio gameitself/headless-2.1.23/factorio/bin/x64/factorio \
  --client-base gameitself/base-2.1.23/factorio/bin/x64/factorio \
  --client-space-age gameitself/space-age-2.1.23/factorio/bin/x64/factorio \
  --archive "$ARCHIVE" --output "$WORK/verification" \
  --quick --ticks 120 --warmup 120 --repetitions 1
```

This executes every named case in both content modes and all three measurement
lanes at one representative scale. It is functional verification, **not** the
full scaling baseline. Omitting `--quick` selects every scale; defaults are 600
warmup ticks, 3600 measured ticks and three repetitions. Full matrices are
intentionally expensive. Start with the relevant family, not thousands of runs:

```sh
python3 tools/scheduling_benchmark.py \
  --factorio gameitself/headless-2.1.23/factorio/bin/x64/factorio \
  --archive "$ARCHIVE" --output "$WORK/idle-baseline" \
  --cases 'idle/*' 'computer/*' dispatch/one-plus-idle --lanes timing structure
```

`--cases` accepts quoted shell-style patterns; unmatched selectors are errors.
`--list` prints the fully expanded selection without running engines. Every
output directory must be new and outside the checkout. Raw receipts survive
failures. Exit status is nonzero if any requested run fails.

For before/after comparisons, pass `--baseline /absolute/baseline.zip` and
`--archive /absolute/candidate.zip`. The runner uses the same fixture for both,
runs serially, and alternates baseline/candidate order between repetitions.
Compare an identical archive against itself first to assess host noise. Do not
run another engine benchmark concurrently. The report includes paired CPU deltas
and callback-count changes, excluding failed pairs; it is not an automatic
statistical significance or performance acceptance decision.

## Matrix

There are 62 named cases and 235 expanded configurations before multiplying by
content modes, lanes, repetitions and archives. The executable inventory is
`--list`, not this count. Counts mean the population named in the table, not an
identical total entity count across unrelated cases.

| Family | Cases | Isolated work / oracle |
|---|---|---|
| Empty | `empty/no-devices` | Same powered map, no mod devices |
| Idle | `idle/computer`, `kv`, `monitor`, `logic`, `configurator`, `recipe_searcher`, `factoriopedia_interface`, `production_statistics`, `dashboard` | Settled family, no guest program; physical maintenance remains |
| Native idle | `idle/native-radar`, `idle/native-speaker` | Unconnected native entities; power/existence checked, no computer discovery interest |
| Computer | `computer/stopped`, `computer/waiting` | Stopped versus a running idle declaration program; no timer, subscription or queued work |
| Dispatch | `dispatch/one`, `one-plus-idle`, `all` | Fixed one-ready producer versus increasing idle population, then ready fan-out; actual completions and enqueue-to-handler latency |
| Console | `dispatch/console`, `arbitration` | Native Console alone or alongside program work; both completion counts retained |
| Timer | `timer/future`, `sparse`, `staggered`, `burst` | Future deadlines, one due stream, distributed deadlines, simultaneous deadlines; callback lateness and retained timers |
| Signal | `signal/unwatched`, `watched-static`, `watched-changing`, `shared-input`, `distinct-inputs`, `pulse` | Inventory without interest, unchanged subscriptions, changed values, shared versus independent inputs; native input width, subscription counts, delivery latency; one-tick pulses counted per subscriber |
| Topology | `topology/no-interest`, `stable-interest`, `rewire`, `adoption` | Connected graph without subscriptions, stable attach/detach interest, cut/reconnect, native radar adoption; notifications/adoption checked |
| Output | `output/no-owner`, `stable-owner`, `revoked-owner` | Safety discovery versus owned output; a disconnected owner must be cleared within the production fail-safe deadline |
| Monitor | `monitor/static`, `one-dirty-row`, `one-dirty-frame`, `all-dirty-row`, `all-dirty-frame`, `regroup` | Every screen initialized; static producers stopped, one/all keep updating; small first-row write versus full-frame blit; actual publication counts/gaps and completed regroup |
| KV | `kv/persistent`, `future`, `staggered`, `burst` | Sixteen keys/device, persistent or TTL deadlines; read-visible expiry and live-key retention checked |
| Art | `art/static`, `running-animation` | Stopped computer status versus running idle animation; no periodic guest callback |
| Native UI | `ui/closed`, `editor-static`, `editor-changing`, `inspector-static`, `inspector-changing`, `dashboard-static`, `dashboard-changing`, `dashboard-chart-static`, `dashboard-chart-changing` | Closed/native editor/Console/KV inspector/dashboard with stable or changing content; chart dependency present only for explicitly named chart cases |
| Churn | `churn/register-cancel`, `activate-stop` | Demand registration/cancellation or repeated activation/stop; no retained canceled timers/subscriptions |
| Cold recovery | `reload/pending` | Separate server process saves pending queue/timer/monitor work; clean quit, separate process reload, no startup replay and exact-once callbacks |
| Mixed | `mixed/sparse`, `busy` | One active signal/KV/monitor system plus idle computers versus many independent active systems |

Axes:

- Idle population: 0, 64, 256, 1024. `dispatch/one-plus-idle` adds one active
  computer. Other idle controls use exactly the requested population.
  Exception: `idle/monitor` uses 0, 64, 128, 256 because production placement caps
  monitor tiles at 256. No benchmark raises that limit; the rejected 1024-tile
  validation attempt is not a performance measurement.
- Active population: 1, 8, 32, 64. Device/screen populations: 1, 8, 32.
- Signal width: 1 or 32 distinct native signals, independent of subscriber count.
- Timer population: 1 or 16 timers per computer, independent of computer count.
- Topology: chain or branching graph; the same root owns interest.
- UI, churn, cold recovery and single-producer controls have fixed size.
- `--quick` selects 8 for population axes and 1 for fixed cases, one signal,
  one timer/computer, chain topology. It does not secretly shorten durations.

`watched-changing` is the changing-input control; `shared-input` intentionally
repeats its shared-input topology for comparison with `distinct-inputs`.
`mixed/sparse` uses the active-population axis for its unrelated idle count.
Monitor cases currently use separate one-tile screens; regroup adds one adjacent
tile. They do not establish large multi-tile-wall rendering performance.

## Evidence lanes

1. `timing`: native headless `wholeUpdate` samples, nanoseconds converted to ms.
   Exact simulation ticks exclude setup, activation, warmup and final report
   serialization. No forwarding profilers or structural counters are installed.
   Workload driving and completion observation are still part of whole-update
   cost. The cold case intentionally includes its first resumed tick.
2. `profile`: inclusive scheduler and registered phase `LuaProfiler` timings,
   plus accumulated timer/dispatch call timings. Every phase must have the exact
   sample count. Overlapping inclusive times must **not** be summed; profiling
   overhead makes these diagnostic, not an uninstrumented speedup claim.
3. `structure`: actual loop visits, function calls, native input reads and render
   object creation. Test-only changes are restricted to an inventoried archive
   copy. Counters are attributed to scheduler phases and never treated as CPU.
   They cover named observer sites, not every operation the engine performs.
   Source-layout changes can require reviewing observer patterns before comparing
   a future scheduling implementation.

All lanes record workload correctness and useful work. Faulted or unpowered
producers, missing receipts, duplicate samples and failed engine exits cannot
become passing low-cost results. Whole-update includes physical entities and
power helpers: removing those later is not purely a scheduler improvement.

Native client cases retain `render-perf.csv` and renderer information. That CSV
has no simulation-tick key: its summary covers the entire process including
warmup and must not be pooled with the measured scheduler window. Client timing
rows deliberately have no headless whole-update statistic. Use the profile lane
for window-aligned simulation attribution. Xvfb/llvmpipe results are not hardware
GPU FPS or connected multiplayer evidence.

Use `--capture` in a **separate** diagnostic run to save `benchmark-ui.png` with
native GUI visible; inspect those images. Captured timings include screenshot
cost and are not acceptance timings. Capture is off by default.

## Report and retained files

- `report.md`: self-contained Markdown, overview table, phase distributions,
  useful work, latency summaries, structural totals, paired comparisons and
  limitations. Copy this note into LLM-Wiki if desired; no plugin is needed.
- `manifest.json`: requested run inventory, actual results, host/engine/source
  identity, exact command and harness hashes. Reconcile expected and completed
  keys before accepting an interrupted run.
- `harness/`: exact runner, helpers and Lua fixtures used for the run.
- Each case directory: isolated input save/config/mods, original/test archive
  hashes, changed-payload allowlist, command receipts, complete engine logs,
  per-tick raw timing values, result JSON and sampled host contention.
- Cold cases additionally retain the snapshot, first-process logs and normal
  console-shutdown receipt. Failed attempts remain separate from successful runs.

The report embeds results rather than depending on relative asset links, so it
remains readable after filing. Raw evidence paths still refer to the original
host. Preserve the entire output in `/home/siredvin/artifacts/tweaked-computers/`
before scratch expiry; never include game distributions or display credentials.

Regenerate a report without running Factorio:

```sh
python3 tools/scheduling_benchmark.py --report /absolute/evidence/manifest.json
python3 -m unittest discover -s tools -p 'test_scheduling_benchmark.py'
```

This harness is benchmark-only. It neither implements demand-driven scheduling
nor increases a production allowance to make a workload pass.
