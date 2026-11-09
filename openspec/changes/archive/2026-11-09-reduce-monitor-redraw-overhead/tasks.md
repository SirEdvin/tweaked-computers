# Tasks

Each task names its verification. Run packaged engine checks with the headless 2.1.23 engine from `AGENTS.md`, using fresh scratch directories. Keep logs and evidence outside git.

## 1. In-place cell changes

- [x] 1.1 Record glyph/color changes for cells with a valid front object in `scripts/rendering.lua`, and apply them in `commit` of `scripts/monitor-presentation.lua` after the visibility swap. Verify with `tests/monitor_component_contract.lua` (`--cold`): changed glyph and colors keep their objects, a cancelled frame leaves the old glyph, a saved ready frame shows the old glyph until its commit after reload, and palette changes update in place.
- [x] 1.2 Verify `monitor_engine`, `monitor_buffer_engine`, `monitor_feedback_engine`, `monitor_presentation_engine`, `monitor_budget_engine`, `monitor_demand_engine` and the `monitor_state_*` fixtures with `--mode both`, and the four-walls and mixed `tools/monitor_animation.py` runs.

## 2. Cheaper host checks

- [x] 2.1 Use `force_index`/`surface_index` in `lifecycle.connector` and remove the duplicate connector proof in `monitor.available`. Verify with `network_engine`, `device_engine`, `lifecycle_engine` and the monitor fixtures.
- [x] 2.2 Key the compiler cache by mode and source, and create one guarded body for each service. Verify with `compiler_cache_contract`, `runtime_environment_contract`, `computer_contract` and `runtime_scaffold_engine`.

## 3. Verification

- [x] 3.1 Run the 49-fixture smoke inventory of `idle-scheduler-candidate-2026-11-07/matrix-final` plus the three monitor fixtures above with `--mode both`, and `tools/test_build.py`. Verify that every fixture passes.
- [x] 3.2 Record matched `tools/monitor_performance.py` results for one 6×6 wall (baseline, candidate, candidate repeat) under `/home/siredvin/artifacts/tweaked-computers/`. Claim no gain beyond the measurement.

## Workflow follow-up

- Sync the delta specs into `openspec/specs/` and archive the change in the same pull request.
