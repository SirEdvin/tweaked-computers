# Tasks

Each task names its verification. Run packaged engine checks with the headless 2.1.23 engine, using fresh scratch directories. Keep logs and evidence outside git.

## 1. Guarded calls

- [x] 1.1 Add `E.borrow_input`, the measuring `copy()` and the pooled-frame path for borrowed calls in `scripts/runtime/environment.lua`. Verify with `runtime_environment_contract`, `runtime_contract`, `computer_contract`, `shell_contract`, `native_admission_contract` and `runtime_budget_engine`.
- [x] 1.2 Reuse resolved peripheral identities per inventory proof in `scripts/services/peripheral.lua`. Verify with `device_contract` and the monitor fixtures.

## 2. Graphics calls

- [x] 2.1 Borrow graphics props, measure the payload and reuse unchanged stored properties in `scripts/monitor-graphics.lua` and `scripts/services/monitor.lua`. Verify with `monitor_graphics_contract`.
- [x] 2.2 Add the text and colour fast path for `set`. Verify with `monitor_graphics_contract`.

## 3. Verification

- [x] 3.1 Run the 52-fixture inventory of `monitor-redraw-candidate-2026-11-09`, the five monitor extras, the four animation runs, the upgrade from 0.1.21 and the combined envelope campaign, all with `--mode both`, plus the tools unit tests. Verify that every check passes.
- [x] 3.2 Record per-call slope and six-line stock results under `/home/siredvin/artifacts/tweaked-computers/monitor-graphics-call-candidate-2026-11-09/`. Claim no gain beyond the measurement.

## Workflow follow-up

- Archive the change in the same pull request. It has no delta specs (`skip_specs`).
