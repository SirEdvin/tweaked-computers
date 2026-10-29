# Tasks

Goal: replace raw Console tick prefixes with elapsed map time as specified in `specs/program-editor/spec.md`.

Approach: change only the shared presentation in `scripts/ui/editor.lua`, using Lua arithmetic and integer formatting. The inspected Factorio 2.1.23 `util.formattime` returns minutes and seconds only, so it does not implement the agreed format. Keep any formatting logic local; add no module, export, setting or dependency.

Boundary: this change is currently planning-only. Implementation requires a separate apply request. `design.md` is deliberately omitted under its conditional instructions: there is no cross-cutting architecture, data-model change, migration complexity or unresolved technical decision.

## 1. Elapsed timestamps with regression coverage

- [x] 1.1 Add table-driven Console rendering assertions in `tests/editor_workspace.lua` for the exact tick/prefix pairs in the spec, including subsecond flooring, minute/hour rollover, 24 hours and 100 hours. Verify the new assertion fails against raw-tick rendering, then minimally update `console(rec)` in `scripts/ui/editor.lua` and verify it passes. Assert that old entries remain unchanged as the viewing tick advances and after reopening/restarting, without changing stored ticks, text or byte accounting; retain existing Follow, selection/write-count and truncation assertions.
- [x] 1.2 Extend `tests/shell_contract.lua` to assert the shared prefix on command echoes, printed/expression results and logged errors alongside program output. Verify the fixture passes with attribution, nil/false behavior, original stored text, tab/newline display normalization and focused drafts unchanged.
- [x] 1.3 Extend `tests/editor_cold.lua` with retained raw-tick entries, snapshot their ticks/text/byte accounting and verify the same formatted output after a separate-process save/reload. Preserve the fixture's existing draft/source divergence, spent-credit and once-only/no-startup-replay assertions; both cold-phase receipts must pass.
- [x] 1.4 Update `docs/player/console.md` to explain elapsed map time, completed seconds, cumulative hours and simulation-speed/pause behavior. Check its examples against the spec and tests; do not describe a wall clock, computer uptime or a configurable display.

## 2. Packaged and native verification

- [x] 2.1 Build a fresh archive outside the checkout with `python3 tools/build.py --output <scratch-package-dir>`. Against that exact archive, run `python3 tools/smoke.py --factorio <verified-2.1.23-engine> --archive <archive> --output <fresh-outside-repo-dir> --mode both` separately with `--fixture tests.editor_workspace`, `--fixture tests.shell_contract`, and `--fixture tests.editor_cold --cold`. Verify every expected base/Space Age result, exact archive identity, cold completion markers and clean exits; retain failures rather than weakening assertions. Run `git diff --check`.
- [x] 2.2 Perform a focused smoke check in an isolated matching 2.1.23 full client: inspect ordinary and long-hour prefixes, copy literal output, disable Follow while new messages arrive, and reopen the Console. Verify readable timestamps, unchanged attribution and no new selection/scroll regression; keep screenshots outside git. A headless/mock pass is not native-client acceptance. If the matching client is unavailable, report that gate as incomplete rather than using the older 2.0.77 client paths in historical docs.
