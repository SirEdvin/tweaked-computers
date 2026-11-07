# Tasks

Each task names its verification. Run packaged engine checks with the headless 2.1.23 engine from `AGENTS.md`, using fresh scratch directories. Keep logs and evidence outside git.

## 1. Report callback overhead

- [x] 1.1 Keep the loaded program chunk on the run-scoped scaffold entry in `scripts/runtime/compiler.lua`. Extend `tests/runtime_scaffold_engine.lua` to count guest-program loads: one per run for warm callbacks, one per cold callback, one for a new run. Verify the fixture passes with `--mode both`.
- [x] 1.2 Pass string arguments of `print` directly in `scripts/runtime/environment.lua`, and remove a single evicted Console entry with `table.remove` in `scripts/runtime/computer.lua`. Verify `tests.computer_contract` and `tests.runtime_environment_contract` pass with `--mode both`.

## 2. Verification

- [x] 2.1 Run the smoke fixture inventory of `idle-scheduler-candidate-2026-11-07/matrix-final` against the candidate archive with `--mode both`, including its cold and production-context flags. Verify every fixture passes.
- [x] 2.2 Run the chest benchmark (`chest/*`, base, profile and timing lanes) and the recovered 600-tick runner against the `main` archive and the candidate, serially on the same host. Record report-tick and other-tick timing, hashes and host contention under `/home/siredvin/artifacts/tweaked-computers/`. Claim no speedup beyond the measured result.

## Workflow follow-up

- Sync the delta spec into `openspec/specs/computer-runtime/spec.md` and archive the change in the same pull request.
