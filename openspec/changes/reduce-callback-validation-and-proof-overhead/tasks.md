# Tasks

Each task names its verification. Run packaged engine checks with the headless 2.1.23 engine, in fresh scratch directories. Keep logs and evidence outside git.

## 1. Run-scoped source validation reuse

- [ ] 1.1 In `scripts/runtime/compiler.lua`, keep the validated handler set in the run scaffold entry and skip `compiler.compile` for a paid callback with a matching entry that has a loaded chunk. Verify in `tests/runtime_scaffold_engine.lua` with a count of validations: warm later callbacks make none, a cold peer copy makes one without a compilation charge, and a new run or a changed source validates again.
- [ ] 1.2 Add a contract to `tests/runtime_scaffold_engine.lua`: compile more distinct other sources than the shared cache holds between two callbacks of a running program. Verify that the second callback makes no validation and has the same ledger total and effects as the first warm callback.
- [ ] 1.3 Set the shared source cache capacity to `limits.active_computers`. Make `evict()` in `tests/compiler_cache_contract.lua` use that capacity plus one. Verify that `tests.compiler_cache_contract` passes with all its warm and cold comparisons and its bounded-eviction check.

## 2. Computer methods preserve callback-local proofs

- [ ] 2.1 In `scripts/runtime/computer.lua`, classify `getID`, `getLabel`, `setLabel`, `getTick`, `getLimits`, `getState`, `setState`, `deleteState`, `log`, `on`, `off`, `after`, `every` and `cancelTimer` with `guard.stable_service`. Verify with a new contract that counts network discoveries: for each listed method, `wrap`, then the method, then a proof-preserving peripheral call makes one discovery.
- [ ] 2.2 In the same contract, verify equal ledger totals, results and errors for the two call orders (computer method before `wrap`, and between `wrap` and the peripheral call). Verify that a peripheral method without a stability classification still causes a new discovery for the next call.
- [ ] 2.3 Verify in `tests/shell_contract.lua` that a Console command with a listed method between two peripheral calls makes one discovery, and that the refused Console registration methods return their existing error.
- [ ] 2.4 Verify that the existing ownership and topology contracts pass unchanged: `reused-scaffolding-rechecks-authority-and-topology` in `tests.runtime_scaffold_engine`, `tests.network_engine`, `tests.computer_contract` and `tests.runtime_contract`.

## 3. Documentation

- [ ] 3.1 Update `docs/computer-runtime.md`: add the 14 methods to the reviewed-boundary table and correct the sentence about source validation on later callbacks. Regenerate the reference provenance with `tools/player_docs.py`. Verify with `tools/player_docs.py --check` and `tools/player_docs.py --check --change reduce-callback-validation-and-proof-overhead`.

## 4. Verification

- [ ] 4.1 Run the smoke inventory of `/home/siredvin/artifacts/tweaked-computers/monitor-redraw-candidate-2026-11-09/matrix/inventory.json` with `--mode both` and its recorded flags, the five monitor fixtures of the 0.1.22 gate set, and the four-walls and mixed monitor animations. Verify that each run exits 0 and that no receipt has `"passed": false`.
- [ ] 4.2 Run the six-line stock benchmark (`tools/monitor_performance.py --program`, terminal and graphics, `--scene one --ticks 3600`) in the order baseline, candidate, baseline, serial. Record the update-tick medians and the allocation for each update. The ablation values are 1.66 ms to 1.68 ms (terminal) and 1.24 ms to 1.26 ms (graphics).
- [ ] 4.3 Run `tools/scheduling_benchmark.py --cases 'chest/*'` (profile lane) for baseline and candidate as a control. Verify that the report-tick values stay within the run-to-run spread of the baseline.
- [ ] 4.4 Run the scratch microbenchmark of the evidence directory (`bench_exec.lua`, `bench_ablation.lua`) on the candidate. Record the time for each callback with 9 and 16 distinct programs and the time for each `computer.getTick()` call.
- [ ] 4.5 Save the results of 4.1 to 4.4 under `/home/siredvin/artifacts/tweaked-computers/`. Put the measured before and after values in the pull request. Claim no gain beyond the measurements.

## Workflow follow-up

- Sync the delta spec into `openspec/specs/computer-runtime/spec.md`, archive the change and add the archive directory to `CanonicalContractTests.promoted_changes` in `tools/test_build.py`, in the same pull request.
