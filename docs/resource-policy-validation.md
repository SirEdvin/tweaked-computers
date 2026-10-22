# Resource-policy implementation evidence

This is an **unfinished implementation checkpoint**, not a release candidate or completed resource-policy contract. The approved scope remains all 47 tasks in `openspec/changes/replace-arbitrary-limits-with-resource-policy/`.

## Scope and source

- Implementation base and fetched `origin/main`: `d9e17929620ee9995a6b3235635ac12a283a0e72` (includes the approved planning change).
- Isolated feature branch: `tweaked-computers/t_b473a1fb-implement-approved-configurable-resource`.
- The cancelled signal-read investigation is diagnostic context only; none of its acceptance is inherited. No Ctrl+click work is duplicated. Publication/integration remains downstream card `t_4efacf8e`.
- Durable evidence root: `/home/siredvin/artifacts/tweaked-computers/t_b473a1fb-resource-policy/`. Archives, maps, logs and screenshots do not belong in git.

## Acceptance matrix

| Area | Intended change | Unchanged acceptance |
|---|---|---|
| Program/Console execution | Private durable continuation; work suspension, recoverable capacity refusal | Supported grammar, lexical/evaluation/tuple semantics, authority, deterministic shared credits, source diagnostics |
| Effects and persistence | Retain next uncompleted primitive and pending return delivery | No startup/effect replay, no execution or ledger renewal in `on_load`, cold and late-join equivalence |
| Events | Drop newest with durable visible diagnostics | Accepted FIFO order, timer deadlines, output fail-safes, no silent command/write loss |
| Native inventories | Remove shape/cardinality gates end to end | Complete defensive snapshots, native domains, coherent observations and current authority |
| Monitor | Invocation-aware sealing, resource-owned buffering and named groups | 6×6 axes, atomic publication, at least 360 intervals per mode/layout with maximum two-tick gap; native-render gates |
| Storage/settings | Configurable growth admission, grandfather accepted data | Atomic refusal, reads/deletion/transport after decreases, explicit migrations |
| UI/audio/multiplayer | Visible pressure and complete scrolling/refresh | Real client interaction/audio/render evidence and connected late join, not mocks/headless substitutes |

## Baseline: task 1.3

`baseline/source.tar`, `source-commit.txt`, `source.sha256` and `build.json` freeze the unchanged source and archive. Baseline archive SHA-256: `bb0548550cfee1ecf1accdcaf2aef3ad143dcebd5d878af0914df648ce61b982`.

All runs use Factorio 2.0.77/build 84539, isolated config/mod/write/save directories, and the packaged archive. Both base and Space Age pass:

- `baseline/runtime`: 64 counted contract groups per mode.
- `baseline/computer`: 92 groups per mode, followed by two separate cold server phases.
- `baseline/console`: the production-context shell cold fixture, with two cold phases per mode.
- `baseline/animation-four-walls` and `baseline/animation-mixed`: 360 complete publication intervals per mode/layout, maximum gap two ticks. Each wrapper records its test-only archive and guest hashes separately from the unchanged input archive.
- `baseline/maintenance-unprofiled-v2`: 600 real scheduler samples per mode, 40 input observations each, zero measured input-to-effect tick latency, no faults. Scheduler means 1.370486 ms (base) and 1.451662 ms (Space Age); these are host-specific samples, not a hardware-independent latency promise.
- `baseline/maintenance-profiled-v2`: separate 600-sample phase-instrumented runs, with exact registration-derived profiler inventories. Observer-inclusive timing is not substituted for unprofiled controls.

Successful cold phases have completion markers, acknowledged console `/quit`, zero engine exits and no signal/forced cleanup. Full logs and host-contention samples remain in the bundle.

The first profiled benchmark reported structural failure because its extractor expected 15 phases while production registered 17. That failed attempt remains under `baseline/maintenance-profiled`; it is **not** an accepted timing baseline. Commit `94e1ca9` replaces that stale count with an independently logged registered-phase inventory and exact set/per-phase sample checks. Seven host regressions cover added/missing/duplicate phases and samples. Both profiled and unprofiled controls were rerun as `*-v2`; neither the production budgets nor workload/cadence gates changed.

## Desired red contracts: task 1.2

The added opt-in entry points extend, rather than disable, the existing runtime/computer/cold assertions:

- `red/runtime`: fails against the old runtime with `slice must suspend, not fail: callback budget exhausted`.
- `red/computer`: fails because work pressure retires the active run.
- `red/cold`: fails in the first real server process because no unfinished healthy invocation can be saved.
- `red-capacity`: a separately recorded diagnostic ZIP changes only the two inventoried fixture members of the unchanged baseline. It fails because uncaught capacity exhaustion retires the run. Its provenance explicitly distinguishes the diagnostic bytes from the embedded baseline package manifest.

These are expected red assertions, not candidate acceptance. Complete logs, commands and exit codes are retained, including the nonzero first cold server exit.

## Durable scalar vertical slice (partial tasks 3.1–3.2)

`slice-03/results.json` records four passing packaged fixtures in both engine modes. `slice-03/build.json` identifies the exact tested archive; later edits require a new package and rerun.

- `tests.resource_policy_runtime`: both descriptor/declaration finite scalar loops span paid slices, preserve locals and the completed prefix, and do not renew credits on same-tick retry. A trusted forwarding boundary deliberately exhausts work **after** a service effect; its saved result prevents duplicate delivery on resumption.
- `tests.resource_policy_computer`: the production scheduler preserves an unending invocation, serves a finite neighbor and accepts host Stop without losing accepted state.
- `tests.resource_policy_cold`: a declaration loop resumes after a separate-process cold save with an unchanged graph/ledger and no prefix replay.
- `tests.resource_policy_engine`: real powered/wired computers and KV peripherals use the actual `peripheral.wrap`, captured `db.set`, native service checks and production scheduler. Both source forms save inside finite loops after one database mutation. Cold reload preserves symbolic facade/method aliases, original run, locals, queued FIFO and spent credits; only remaining effects execute, and a finite timer-driven neighbor progresses. The graph is checked for functions, threads, LuaObjects and metatables.

The checkpoint ABI is private and experimental. The scalar lowerer deliberately reports unsupported syntax rather than silently executing an unsupported continuation with a native fallback. The older direct compiler test entry remains during this staged transition; production program dispatch now passes an explicit invocation checkpoint. **Do not publish this intermediate branch:** language coverage, Console integration, aggregate resource accounting, incremental compiler/service preparation, migrations, monitor completion holds and the matched continuation performance gate are not yet complete. No complete task 3.1/3.2 acceptance is claimed from these subset proofs.

## Still required

The source-site disposition audit is not complete. Settings/resources, recoverable capacity handling, non-lossy settings decreases, all language/library/service continuations, event diagnostics, native inventories/UI, complete migration and engine matrix, actual rendering/audio and connected multiplayer remain mandatory. No production budget increase or weaker test gate is authorized by this checkpoint.
