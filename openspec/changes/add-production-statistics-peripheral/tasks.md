# Tasks

Goal: deliver the physical Production Statistics peripheral and its three distinct read operations as one usable, documented feature.

Architecture: a stateless Lua provider behind the existing powered peripheral facade reads native local statistics. Reuse current device lifecycle, guarded callbacks, Data transfer, inspectors and monitor presentation; add no dependency or history collector.

Baseline: `136b3a6`, Factorio 2.1.23, base and optional Space Age. Paths named as new below are proposed; existing integration points were inspected during planning. No implementation or native acceptance has run for this feature.

Authorization: this artifact is planning only. Start implementation only through a subsequent apply request. Use test-first changes inside each milestone: capture an intended failing assertion, make the minimum coherent change, rerun its focused checks, and retain the failure/pass receipts. Never widen budgets, drop assertions or substitute fabricated statistics to obtain a pass. Release publication is not authorized.

## 1. Placeable, researchable statistics device

- [x] 1.1 Add `production_statistics` to `scripts/device-definitions.lua` and the existing `prototypes/devices.lua` generation, with the specified Network-only body, 30 kW power, item/recipe and explicit `technology='tc-recipe-searcher'` unlock. Add proposed `tests/production_statistics_data.lua` plus relevant device/lifecycle fixture cases and initial placement/progression documentation at proposed `docs/player/api/production-statistics.md`. Verify an initial missing-device contract fails, then pinned-engine prototype loading and exact footprint, recipe, stack, technology ownership and visible connector assertions pass in base and Space Age; preserve Recipe Searcher research cost, prerequisites and its existing recipe unlock.
- [x] 1.2 Add the distinct statistics instrument through `assets/service_rack.py`, generated sprite metadata/assets, locale entries and their manifests/provenance; extend fixed family artwork contracts such as `assets/engine-contract.lua` and `assets/engine-data.lua` without weakening existing checks. Update artwork/provenance documentation. Verify `python3 assets/check.py --output "$WORK/art"` reproduces the new assets, existing unrelated asset bytes remain unchanged, and contact-sheet review covers every cardinal view/state; reserve native appearance acceptance for task 4.2.
- [x] 1.3 Exercise the shared `scripts/lifecycle.lua` unlock and owned-helper paths, changing them only where the additive device actually requires it. Add proposed `tests/production_statistics_upgrade_engine.lua` and lifecycle fixture coverage, documenting upgrade/rollback in the feature guide. Verify fresh Recipe Searcher completion unlocks both recipes, and a copied prior-release save in a separate process enables the statistics recipe only for forces with Recipe Searcher researched while Circuit-Computers-only forces remain locked. Preserve existing devices/data/wires and pass mine/clone/blueprint/drop/helper-cleanup assertions without storing or resetting native statistics.

## 2. Working native query API through the actual guest boundary

- [x] 2.1 Create proposed `scripts/services/production-statistics.lua`, load it during `control.lua` parsing, and register the exact four-method family through `scripts/services/peripheral.lua`. Implement `getTotals` and `getLimits` first; add proposed `tests/production_statistics_contract.lua` and `tests/production_statistics_engine.lua`, and extend `tests/api_inventory.lua` plus its actual fixture scenes together. Verify the missing-method regression fails before implementation and then real compiled guest calls return complete detached native maps, preserve all item qualities and direction-specific keys, and expose no statistics write/reset method. Update the API guide alongside these methods.
- [x] 2.2 Implement `getRates` and `getHistory` against the pinned native `category`/precision/sample API with the documented argument validation, rate units, quality default and exact `{tick,input,output}` shape. Extend the same fixtures and guide with all precision windows, valid-but-unrecorded identities, zero/fractional values, native reset/current-tick timing, modded identities, and actual pollution source/sink keys including relevant Space Age pollutant cases. Verify through actual guest dispatch that bulk rates preserve every recorded key and both history arrays match every direct native sample in all supported windows; no reduced sample set or synthetic history can satisfy this task.
- [x] 2.3 Exercise input failures, provider errors, detached mutation, scope/power/captured-method revocation and shared accounting in the production-path fixture, with narrowly labelled host doubles only for inaccessible failure injection. Retain existing work/allocation/Data admission rather than adding new statistics caps or settings, and document whole-result refusal in the guide. Verify two forces/two surfaces, explicit wire isolation, unpowered `getLimits`, replaced/removed/moved devices, repeated-read credit consumption, a successful representative bulk/history read, and complete refusal under real existing result/work pressure with no partial return, native mutation or retained query state.

## 3. Usable inspection, examples and shipped reference

- [x] 3.1 Extend `scripts/ui/peripheral-inspector-model.lua`, `scripts/ui/peripheral-inspector.lua`, `scripts/ui/editor.lua` and `scripts/ui/help.lua` family/type/icon/topic inventories for identity/status-only inspection. Extend the existing inspector/Reference tests and feature guide. Verify normal opening and exact-name copying work with and without power, stale/foreign sessions fail closed, refresh invokes no statistics query, and existing peripheral/native GUI gestures remain unchanged.
- [x] 3.2 Add proposed `examples/production-statistics-program.lua` and `examples/production-statistics-monitor.lua`, plus a self-contained in-game Reference tutorial and matching guide. Reuse the existing monitor API for a labelled rates/history dashboard, not a new runtime renderer or stored history. Update `tools/player_docs.py`, `tools/planning_examples.py`, `tests/reference_tutorials_engine.lua` and actual integration scenes as applicable. Verify examples compile and execute from the packaged archive, exercise each category and statistical operation, use the documented wire/power setup, distinguish empty data from refusal, and display history in the intended direction without modifying the API's native order.
- [x] 3.3 Synchronize the approved delta/API contract into canonical documentation through the normal OpenSpec sync workflow without archiving this unfinished implementation; extend `tools/build.py`, `tools/test_build.py`, documentation navigation and explicit API/example inventories. Verify the canonical spec and Lua companion are shipped without active-change path dependencies, `python3 tools/test_build.py`, `python3 tools/planning_examples.py --check`, and the existing strict MkDocs/player-doc checks pass. Preserve unrelated changes and historical evidence; do not implement an engine port while aligning the stale lifecycle engine declaration.

## 4. Exact-package end-to-end acceptance

- [ ] 4.1 Extend the existing explicit test-fixture allowlists in `control.lua` and `tools/smoke.py` for the proposed production-statistics fixture, preserving production-context isolation. Build one candidate outside the checkout and run the new fixture plus relevant existing integration, lifecycle, inspector and API-inventory checks on 2.1.23 base and Space Age, including separate-process cold phases and the previous-release upgrade. Verify every required phase marker, expected scenario inventory and clean exit against the exact archive; creation-only success must not stand in for cold assertions.
- [ ] 4.2 Use an isolated full 2.1.23 client with matching data in each content mode to compare native item/fluid/pollution chart values, quality selections and history against the peripheral at controlled observation points. Exercise placement, every rotation, red/green contacts, power/status changes, normal inspection/name copy and the maintained Reference/monitor workflows. Verify actual screenshots/observations, permitting native display rounding, documented sample boundaries and verified pinned-engine GUI presentation smoothing only; retain the burst case, compare all 300 raw API samples per side directly with native get_flow_count, and keep any smoothing calculation in verification/presentation comparison, never in API data; preserve captures outside git and report unavailable clients or mismatches as unmet gates.
- [ ] 4.3 Exercise actual connected clients, a late join and a cold server restart in both content modes with the packaged candidate and production-path queries. Verify peers agree on scope, complete key sets, native values/sample order and identities; check desync diagnostics and clean shutdown. Keep these receipts distinct from independent headless tests and host doubles.
- [x] 4.4 Measure idle installed devices and repeated representative bulk/history polling under unchanged production settings, with a matched baseline/control and neighboring active computers. Verify there is no new periodic statistics collector or retained history, actual shared-credit consumption is enforced, and timing evidence distinguishes native-call cost from work counters and GUI recording overhead. Preserve any non-fitting complete query or performance failure and reopen that narrow decision rather than adding async jobs, truncation or higher limits.
- [ ] 4.5 Consolidate verification at proposed `docs/production-statistics-validation.md`, binding each required success or failure to source revision, archive hash, engine/content mode, fixture/client phase and exit/observation. Run strict validation of this change, `git diff --check`, package/documentation checks and required exact-head CI after the implementation is committed/pushed on its feature branch. Verify all named acceptance gates are accounted for and no existing peripheral signatures/tests were silently removed; mark implementation complete only when the required gates actually pass.

## Command anchors for the implementation phase

These are planned invocations, not results. Use an isolated `$WORK` under the configured scratch directory and a verified `$FACTORIO` executable whose `--version` is 2.1.23. Do not reuse a live save, assume the old AGENTS binary path is current, or invent flags for client/upgrade helpers; use their inspected help and existing harness conventions.

```sh
python3 tools/test_build.py
python3 tools/planning_examples.py --check
python3 -m mkdocs build --strict --site-dir "$WORK/site"
python3 tools/player_docs.py --check --site "$WORK/site" --report "$WORK/player-docs.json"
python3 tools/build.py --output "$WORK/package"
```

After the new fixture exists and both explicit production-context allowlists include it, run the proposed focused native gate with the actual candidate `$ARCHIVE`:

```sh
python3 tools/smoke.py --factorio "$FACTORIO" --archive "$ARCHIVE" \
  --output "$WORK/statistics-smoke" --mode both \
  --fixture tests.production_statistics_engine --production-context --cold
```

Expected outcome: the new scheduled native assertions execute in every required process phase, direct engine and actual guest observations agree, and all processes exit cleanly. A command exit alone, source-only inspection or a creation-phase marker is insufficient.

## Workflow follow-up

- After implementation acceptance and review, archive through the normal OpenSpec workflow and verify the canonical spec/API companion and active-change inventory. Do not archive merely because planning files exist.
- A versioned release or Mod Portal publication requires separate explicit authorization and the exact verified artifact. Restore a pre-upgrade backup for rollback; do not promise safe downgrades of saves containing the new entity.
