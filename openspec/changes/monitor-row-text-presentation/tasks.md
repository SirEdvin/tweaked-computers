# Tasks

Each task names its verification. Run packaged engine checks with the headless 2.1.23 engine and full clients from `AGENTS.md`, using fresh scratch directories. Keep logs, captures and evidence outside git.

## 1. Font and visual gate

- [x] 1.1 Add `tools/terminal_font.py` (atlas → `assets/fonts/tc-term.ttf`, U+E000+byte, plus a full-block glyph at U+E100). Register the font in `assets/manifest.json` and extend the derived-output check in `tools/build.py` to `assets/fonts`. Verify that `tools/test_build.py` passes and that a changed atlas makes the build fail as stale.
- [x] 1.2 Add the `font` entry to `locale/en/info.json` and the `tc-term` FontPrototype in `prototypes/monitor.lua`. Verify that headless `--create` loads without errors.
- [x] 1.3 Run gate D6 with a test-only scene in the base and Space Age clients. Cover zoom 0.5/1/2/4, all four directions, font metrics/`vertical_alignment`/offset variants, the selection box, wires and the deconstruction marker above the text, cloud shadows, and the `ru`/`ja`/`zh-CN` locales. Record the pixel diffs against the sprite baseline in `/home/siredvin/artifacts/tweaked-computers/`. Then select rectangle or text backgrounds (D3) in `design.md`. Stop for review if text draws above native feedback.

## 2. Row model

- [x] 2.1 Replace cell tables with row strings and row damage in `scripts/monitor-model.lua` (write, blit, clear, clearLine, scroll, capture, acknowledge, resize, settings inherit). Add `model.cell(m,x,y)`. Verify with `tests/monitor_snapshot_contract.lua` and `tests/monitor_optimization_contract.lua`. Their work charges, refusal points and read-after-write results must be identical.
- [ ] 2.2 Migrate every fixture that reads `model.cells` (`grep -rln "\.cells" tests`) to `model.cell` without removing assertions. Update the shape validation in `scripts/services/monitor.lua`. Verify that `monitor_engine` and `monitor_state_*` pass with `--mode both`.

## 3. Row presenter

- [ ] 3.1 Rewrite `scripts/rendering.lua` for D2–D4: prepare builds row data; commit sets texts and background runs and creates or destroys only the difference. Adapt the loop unit in `scripts/monitor-presentation.lua` to rows, and keep cell-denominated admission. Verify with `tests/monitor_component_contract.lua` (`--cold`): a changed row keeps its object identities, a cancelled frame owns no objects, a saved ready frame publishes after cold reload, and a palette change updates the rows in place.
- [ ] 3.2 Add a rich-text injection regression: guest text `[color=red]x[/color][img=item/iron-plate]` shows literal glyph cells. Add an object-count assertion for a 126×84 three-run chart (spec: Row text presentation). Verify with `monitor_engine --mode both`.
- [ ] 3.3 Rerun `monitor_buffer_engine` (`--cold`), `monitor_feedback_engine` (`--cold --production-context`), `monitor_presentation_engine`, `monitor_budget_engine` and `monitor_demand_engine`, and both `tools/monitor_animation.py` layouts. Rewrite assertions that expect destroyed cell sprites to the row-identity contract. Verify that all pass in both modes.
- [ ] 3.4 Hide the row text of a display while any member tile is marked for deconstruction, and restore it on cancel (D8). Verify with an engine fixture: mark one tile of a published wall, check every row object is hidden and the model revision is unchanged, publish a new frame while marked and check it stays hidden, cancel and check the new content is visible.

## 4. Upgrade

- [ ] 4.1 Extend synchronized enrolment for D7 (cell model → rows, legacy cell front retired at the first row commit, unknown shapes fail closed). Extend `tests/monitor_upgrade_engine.lua` with a save from the previous release that holds a populated 6×6 display, a front and a pending frame. Verify the same content, zero leftover cell sprites and quiescent settled ticks after the upgrade.

## 5. Visual and performance acceptance

- [ ] 5.1 Capture the final package in the base and Space Age clients (zoom 0.5/1/2/4, four directions, a marked display). Compare decoded pixels with the gate baseline. Store the captures in the artifacts bundle.
- [ ] 5.2 Add `--workload dense` (6×6 wall, scale 0.5, chart without the 32×22 cap) to `tools/monitor_performance.py`, with a test in `tools/test_monitor_performance.py`. Record matched baseline/candidate/baseline runs for the single wall, the four walls and the dense workload. Report mean, median, p95 and maximum without thresholds.
- [ ] 5.3 Update `docs/monitor.md`, `docs/monitor-performance.md` and `docs/player/monitor-animation.md` (row presentation, font, measured numbers, known appearance differences). Then run the smoke inventory with `--mode both` and `tools/test_build.py`. Verify that every fixture passes, and record `Reviewed-source` with `tools/player_docs.py --check --change monitor-row-text-presentation`.

## Workflow follow-up

- Sync the delta specs into `openspec/specs/` and archive the change in the same pull request.
