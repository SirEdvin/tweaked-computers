# Tasks

Each task names its verification. Run packaged engine checks with the headless 2.1.23 engine from `AGENTS.md`, using fresh scratch directories. Keep logs and evidence outside git.

## 1. Buffered program output with one charge

- [x] 1.1 Route program `print` and `computer.log` through a per-callback buffer in `scripts/runtime/computer.lua`/`environment.lua`. Flush it in every `compiler.run` exit path. Make direct `M.log` flush pending output first. Verify with a new contract in `tests/computer_contract.lua`: interleaved print/log order, a fault after print (output before the diagnostic), stop, and equality of entries, bytes and truncation flag with immediate appends under entry and byte pressure.
- [x] 1.2 Charge a program `print` twice (`n+1` before conversion, then `(bytes+1)+4`), plus a one-time eviction charge per callback. Verify that a refused print at each allowance boundary publishes nothing and fails at the same print, with warm and cold scaffolding. Verify that existing print/Console contracts pass unchanged, or with only charge-value updates that are reviewed one by one. Verify that Console command output and charges are unchanged.
- [x] 1.3 Update `docs/computer-runtime.md` and the Console player docs where they describe output timing or print charges. Regenerate the reference provenance with `tools/player_docs.py` and check it with `tools/player_docs.py --check`.

## 2. Cheaper and verified discovery

- [x] 2.1 Read `connector.owner` once and use `force_index`/`surface_index` in `scripts/network.lua`. Verify that `network_engine`, `logic_engine` and `radar_engine` pass with `--mode both`, including cold runs.
- [x] 2.2 Prototype the exact per-callback verification of a cached graph and measure it against `network.discover` on the engine. Keep verified reuse only for a measurable gain. Result: 24.2 µs versus 35.7 µs hot for two devices; reuse was dropped with user approval and design.md records the numbers.

## 3. Verification

- [x] 3.1 Run the 49-fixture smoke inventory of `idle-scheduler-candidate-2026-11-07/matrix-final` with `--mode both` and its cold/production-context flags, plus the four-walls and mixed monitor animations. Verify that every fixture passes.
- [x] 3.2 Record final report-tick numbers (profile lane and recovered runner) against PR #65 (B/C/B) under `/home/siredvin/artifacts/tweaked-computers/`. Claim no gain beyond the measurement.

## Workflow follow-up

- Sync the delta specs into `openspec/specs/` and archive the change in the same pull request.
