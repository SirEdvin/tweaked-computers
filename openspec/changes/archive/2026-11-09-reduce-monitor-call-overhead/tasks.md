# Tasks

Each task names its verification. Run packaged engine checks with the headless 2.1.23 engine from `AGENTS.md`, using fresh scratch directories. Keep logs and evidence outside git.

## 1. Guarded calls

- [x] 1.1 Add the scalar fast path, pooled service frames and vararg `scoped` in `scripts/runtime/environment.lua`. Verify with `runtime_environment_contract`, `runtime_contract`, `computer_contract`, `shell_contract`, `native_admission_contract` and `runtime_budget_engine`.
- [x] 1.2 Build facade methods lazily for programs (`E.lazy_namespace`). Verify with `device_contract`, `peripheral_inspector_engine`, `shell_cold` and `runtime_scaffold_engine`.
- [x] 1.3 Inline the work-charge checks in `scripts/runtime/admission.lua`. Verify with `native_admission_contract`, `runtime_budget_engine` and `scheduling_contract`.

## 2. Monitor work

- [x] 2.1 Share one placement proof per role in `lifecycle.available`. Verify with `lifecycle_engine`, `network_engine`, `device_engine` and the monitor fixtures.
- [x] 2.2 Use a native scan for `blit` colours and a lookup table in the grid write; presize grid copies and mark only changed cells in delta frames. Verify with `monitor_engine`, `monitor_buffer_engine`, `monitor_presentation_engine`, `monitor_component_contract` and the `monitor_state_*` fixtures.

## 3. Verification

- [x] 3.1 Run the 52-fixture inventory of `monitor-redraw-candidate-2026-11-09` with `--mode both`, the four-walls and mixed `tools/monitor_animation.py` runs, and the tools unit tests. Verify that every check passes.
- [x] 3.2 Record serial `tools/monitor_performance.py` results for one 6×6 wall against 0.1.21 and `reduce-monitor-redraw-overhead` under `/home/siredvin/artifacts/tweaked-computers/`. Claim no gain beyond the measurement.

## Workflow follow-up

- Archive the change in the same pull request. It has no delta specs (`skip_specs`).
