# Tasks

Each task names its verification. This change builds on `monitor-row-text-presentation`; start after that change's font gate (its task 1.3) has selected the text offset handling. Run packaged engine checks with the headless 2.1.23 engine and full clients from `AGENTS.md`, using fresh scratch directories. Keep logs, captures and evidence outside git.

## 1. Calibration gate

- [ ] 1.1 Promote the three change-scoped declarations to canonical `api/` and regenerate both references. Verify that `python tools/player_docs.py --check --change monitor-graphics-mode` passes and that `tools/test_player_docs.py` passes.
- [x] 1.2 Run a test-only full-client scene (base and Space Age, normal and low graphics, zoom 1/2/4, four directions). Measure the icon sprite scale for a 64-px box, the default light scale for a contained radius, the stroke extents at widths 1/2/8, and which sprite render layer interleaves with shapes and text above the panel. Check that the selection box, wires and the deconstruction marker draw above shapes. Record the results and captures in `/home/siredvin/artifacts/tweaked-computers/`, and write the constants into `design.md` D4/D5. Stop for review if the cross-type order or native feedback cannot be met.

## 2. Mode and pixel geometry

- [ ] 2.1 Add `mode` to the monitor model, `getMode`/`setMode` with the D8 switch sequence, pixel `getSize`, and `E_UNSUPPORTED` dispatch rules in `scripts/services/monitor.lua`. Add `tests/monitor_graphics_contract.lua`, covering mode switch clearing, the no-op same mode, `E_RANGE`/`E_ARGUMENT` modes, method availability in both modes and resize payloads with reason `mode`. Verify with `--mode both --cold`.
- [ ] 2.2 Implement pixel touch and `mode` fields on touch and resize events, and graphics clearing on tile reconciliation. Extend the existing touch/resize fixtures for a rotated non-square graphics display (spec scenarios: Touch on a graphics display, Add a tile). Verify that `monitor_engine` and the touch fixtures pass in both modes.
- [ ] 2.3 Refuse graphics members in `peripheral.setMonitorSyncGroup` and remove a member that switches to graphics. Verify with a sync-group fixture: the refusal keeps the previous selection, and the remaining members keep publishing rounds.

## 3. Graphics objects

- [ ] 3.1 Add `scripts/monitor-graphics.lua` with the store (D1), the property validation per type, the colour and point forms, and the exact bounds (D3). Add a table-driven pure-Lua test for every type, including exact fit, the rotated text and sprite, the arc sector near an edge and the partial `set` outside. Verify it under the headless engine contract runner.
- [ ] 3.2 Implement the draw methods, `set`, `get`, `getObjects`, `destroy`, `bringToFront`, `moveToBack` and graphics `clear` with the native projection (D2), the calibrated constants and the work charges (D7). Verify with an engine fixture that compares stored props and native object properties, id monotonicity across `clear`, draw order and the same-tick visibility of a callback that later fails.
- [ ] 3.3 Add the native-object count and `E_CAPACITY` checks (D6), shared with the row presenter. Verify with a fixture that lowers only the fixture's view of the limit, fills it with graphics objects, gets `E_CAPACITY` with nothing changed, then succeeds after `destroy`, and that a terminal commit defers instead of exceeding.

## 4. Persistence and transfer

- [ ] 4.1 Add version-2 monitor settings with `mode` in `scripts/lifecycle-data.lua` (paste, blueprint, item tags). Import version 1 as terminal mode. Inherit the mode in merge and split. Verify with lifecycle fixtures: paste graphics onto terminal, blueprint round trip, and split and merge of a graphics wall.
- [ ] 4.2 Add a cold fixture with 500 objects of all types. Verify that after a separate-process load the ids, order, props and native objects are identical and the next id continues. Remove the display and verify zero leftover objects. Load a save from the previous release and verify that all monitors are in terminal mode with unchanged content.

## 5. Inspector, docs and examples

- [ ] 5.1 Show the mode, the pixel size and the object count in the monitor inspector. Verify with the peripheral-inspector fixture and a full-client capture.
- [ ] 5.2 Add `examples/graphics-sine-chart.lua` (polygon curve, axis lines, a title text and an icon). Add a player guide section in `docs/monitor.md` and an in-game Reference tutorial, following the documentation language rules. Verify that the example runs in the showcase scene and that the captures show the chart.

## 6. Acceptance

- [ ] 6.1 Capture the example and a test scene of every type in the base and Space Age clients (four directions, a marked display, cloud shadows). Store the captures and a pixel check of the bounds in the artifacts bundle.
- [ ] 6.2 Run `tools/monitor_performance.py` with the graphics example against the terminal sine example on the same single wall and the dense wall. Report mean, median, p95 and maximum without thresholds. Then run the smoke inventory with `--mode both` and `tools/test_build.py`, and verify that every fixture passes.

## Workflow follow-up

- Sync the delta specs into `openspec/specs/` and archive the change in the same pull request, after `monitor-row-text-presentation`.
