# Tasks

Each task names its verification. Run packaged engine checks with the headless 2.1.23 engine from `AGENTS.md`, using fresh scratch directories. Keep logs and evidence outside git.

## 1. Reproducible chest benchmark and baseline

- [x] 1.1 Add the `chest/poll` case (periods 30 and 600) to `tools/scheduling_benchmark.py` and its workload to `tests/scheduling_benchmark_engine.lua`. Use four chests, 20 items with distinct quantities, one logic handler and `computer.every(period,"report")` printing each entry, plus the existing Console and native-signal audits. Extend `tools/test_scheduling_benchmark.py`, then verify the tool tests pass and a 600-tick preflight run reports exactly one poll with 20 Console entries.
- [x] 1.2 Build the baseline archive from the branch point (`ea02818`) into an external directory. Run the chest case for both periods, base mode: 1-minute ×3 and 5-minute ×3 profiled runs, plus one unprofiled 5-minute run. Verify every run passed with complete samples, and record archive, engine and harness hashes plus host contention under `/home/siredvin/artifacts/tweaked-computers/`.

## 2. Readiness-gated hooks and allocation-free idle ticks

- [x] 2.1 Change `scheduler.register_phase` to require a `ready(root,tick)` function and keep each phase as an array sorted once by name. Call `ready` directly, and enter `try_maintenance` plus `spend(1)` only when it returns true. Verify `tests/scheduling_contract.lua` covers missing/invalid `ready` rejection, fixed order independent of registration order and skipped hooks paying no charge.
- [x] 2.2 Make `M.tick` create the maintenance spend closures, the `due` list and the `ready_round` admission closure only when a hook is ready, a timer is due or the ready set is non-empty. Verify that existing scheduler, fairness, timer and Console arbitration contracts pass unchanged.
- [x] 2.3 Add a `ready` function to every `register_phase` caller, following the design table and each hook's existing early returns. Unknown or unsupported state returns true. Verify that `grep -rn "register_phase(" scripts` shows a readiness argument at every call site, and that the readiness matrix in `tests/scheduling_idle_engine.lua` (exposed through the read-only `scheduler.hook_ready`) shows each hook's own work makes only that hook ready, restoring it makes the hook idle again, and unreadable state reports ready.
- [x] 2.4 Add `tests/scheduling_idle_engine.lua`: one running computer waiting on a recurring timer with no other pending work. On every tick where no hook is ready and no timer is due, assert no maintenance opened and an exactly unchanged `collectgarbage('count')` around `scheduler.tick` for 1,200 ticks, before and after a cold reload, plus exact timer dispatch. Add it to the production-context allowlists in `control.lua` and `tools/smoke.py` and verify it passes with `--mode both --cold --production-context`.
- [x] 2.5 Extend the structure lane in `tools/scheduling_benchmark.py` to count hook invocations per phase. Verify that `empty/no-devices` reports zero hook calls, that idle device and waiting-computer cases call only the due physical-observation hook, and that the active cases still report their expected visits.

## 3. Native status animation

- [x] 3.1 Add `animation` prototypes `tc-status-<kind>-<direction>-blinking` from the existing `blinking` sheets in `prototypes/devices.lua`, and keep the per-frame sprites. Verify with `tests/art_data.lua` that the prototypes exist with 4 frames for each kind and direction that has a blinking state.
- [x] 3.2 Change `scripts/device-art.lua` so the blinking state uses `rendering.draw_animation` (speed 0.1, frame `floor(tick/10)%4`) and arms no deadline. Verify that `tests/art_engine.lua` asserts a running computer has an animation object and no `art` deadline, that state changes still replace art, and that an old-style blinking sprite with a pending deadline converts once without re-arming.
- [x] 3.3 Verify in the full 2.1.23 client, base and Space Age, that a running computer blinks with the same four frames at the 10-tick cadence and that stopped and faulted states are unchanged. Inspect screenshots and sampled video frames, and record evidence outside git. Adjust `animation_offset` if the phase differs.

## 4. Run-scoped host scaffolding

- [x] 4.1 Split `scripts/runtime/environment.lua` into `build(shell)` and `bind(scaffold,context,services)` with one per-callback frame. Keep `environment.new` as `bind(build(shell),...)` for Console and existing callers. Verify that `tests/computer_contract.lua` and `tests/shell_contract.lua` pass unchanged.
- [x] 4.2 Let `runtime.services` and the peripheral provider (`scripts/services/peripheral.lua`) be built once per scaffold and read the tick from a reusable frame. Per-callback setup registers with `guard.on_bind`: it resets the caches and obtains a fresh `principal.proof`. Verify that the existing service, logic, monitor, KV, radar, speaker and dashboard contract fixtures pass.
- [x] 4.3 Add the process-local scaffold cache in `scripts/runtime/compiler.lua`, keyed by computer id and validated against record, run id, generation and active source (no setting is captured at build). Charge the recorded construction total on every bind, warm or cold. Drop entries on retire, fault, stop and removal. Verify with `tests/runtime_scaffold_engine.lua` that warm callbacks construct fresh exports with one scaffold build per run, that warm and cold paths give identical ledger totals and refusal codes under reduced allowances, that a wire removed or restored between callbacks is seen by the later callback, and that a new run rebuilds.
- [x] 4.4 Verify cold reload and connected late join with a running chest program: server and joining client agree on Console output, state and ledger with no desync. Use the existing peer harness pattern and record evidence outside git.

## 5. Documentation

- [x] 5.1 Update player and developer documentation that describes per-tick scheduling cost, status animation or callback reconstruction, using ASD-STE100. Leave `changelog.txt` for release preparation, as the project does. Verify `tools/player_docs.py --check` and the tool unit tests pass.

## 6. Integration

- [x] 6.1 Build the candidate archive and run `tools/smoke.py --mode both` with the cold and production-context fixtures in the CI allowlist, plus `tools/monitor_animation.py` for `four-walls` and `mixed`. Verify all pass with zero exit and no budget changes.
- [x] 6.2 Run the candidate chest benchmark with the same matrix as 1.2, serially and on the same host. Report idle-tick and report-tick mean, median, p95 and max for both periods against the baseline, together with hashes, sample counts and host contention. Make no speed claim beyond the measured results.

## Workflow follow-up

- Close `demand-driven-device-scheduling` task 5.4 separately; this change does not complete it.
- Open a PR from `perf/reduce-idle-scheduler-overhead` after tasks pass, then archive the change after review.
