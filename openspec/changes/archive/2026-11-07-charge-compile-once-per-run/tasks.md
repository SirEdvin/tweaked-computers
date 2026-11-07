# Tasks

Each task names its verification. Run packaged engine checks with the headless engine from `AGENTS.md`, using fresh scratch directories. Keep logs and evidence outside git.

## 1. Compile charge once per run

- [x] 1.1 Read and set the saved `compile_paid` marker in `scripts/runtime/compiler.lua`. Extend `tests/runtime_scaffold_engine.lua`: the first callback pays compilation, later callbacks do not, a cold peer with the same saved record charges and refuses the same, and a new run pays again. Verify the fixture passes with `--mode both`.
- [x] 1.2 Update `docs/computer-runtime.md` and regenerate the reference provenance.

## 2. Verification

- [x] 2.1 Run the compiler, runtime, computer, shell and cold smoke fixtures with `--mode both`, including their cold flags. Verify every fixture passes.

## Workflow follow-up

- Sync the delta spec into `openspec/specs/computer-runtime/spec.md` and archive the change in the same pull request.
