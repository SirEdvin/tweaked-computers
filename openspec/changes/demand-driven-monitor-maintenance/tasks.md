# Tasks

Goal: eliminate unnecessary monitor maintenance for idle and active producers while preserving the behavior in both delta specs and the monitor API companion.

Execution boundary: this is an unchecked implementation plan, not execution evidence. Start only after a new apply request. For each code-bearing task, establish its failing regression, make the smallest root-cause change, and rerun the focused test before proceeding. Keep all production budgets and guest signatures unchanged. Use isolated packaged Factorio 2.1.23 base/Space Age runs; never modify the user's original save or distributions.

## 1. Establish reproducible work and timing baselines

- [ ] 1.1 Freeze the pre-implementation source package and immutable 0.1.16 baseline before production edits; record engine version, archive/guest hashes, mode, scene, scale, budgets and current source revision. Verify production-payload equivalence or explicitly identify differences so inherited changes cannot be attributed to this optimization; preserve baseline receipts outside git.
- [ ] 1.2 Add the proposed `tests/monitor_demand_engine.lua` with production-context/cold registration in `control.lua` and `tools/smoke.py`. Instrument actual topology, full physical proof, capture/preparation, visibility/object and observation boundaries; cover settled 144 tiles, one independent updating screen and active four-screen output. Verify expected baseline failures demonstrate redundant work—not failed setup or unobserved wrappers—and assert live tile/power/producer counts throughout. Document the structural fixture and its counter meanings in `docs/player/monitor-animation.md`.
- [ ] 1.3 Extend existing `tools/monitor_performance.py` and `tests/monitor_performance_engine.lua` with documented zero-monitor, stopped/idle and one-screen-active scene selection while retaining sparse/full-blit all-screen modes. Add focused harness checks beside `tools/test_monitor_animation.py`; verify exact sample/completion/mode validation, matching guest bytes and test-only payload provenance, then capture serial baseline windows. Document the new scene options and distinguish timing reports from pass/fail structural counters.

## 2. Deliver the demand-driven monitor path

- [ ] 2.1 Consolidate monitor observation in `scripts/lifecycle.lua` and relevant registry/status-art paths; remove duplicate generic monitor proofs without unregistering tiles or affecting non-monitor devices. Feed actual topology changes to `scripts/services/monitor.lua` so stable ticks skip signature construction and repartitioning. Verify observation/full-proof counters, same-event native authority, stopped-screen outages/restoration, silent movement/rotation/scope/helper changes and ordinary neighboring-device behavior under unchanged budgets.
- [ ] 2.2 Extend existing `scripts/monitor-presentation.lua` state with deduplicated deterministic demand for singleton/selected lanes; wire successful mutations through `scripts/services/monitor.lua` and existing model/render hooks. Preserve synchronous returns, no-op participation, immutable admitted frames, bounded pending state and fair continued preparation/retirement. Verify the new structural fixture plus snapshot/budget/optimization contracts, including burst writes, later callback failure, writes during preparation, read-only calls and one active screen not waking unchanged peers.
- [ ] 2.3 Connect all non-call wakeups through existing lifecycle, `scripts/lifecycle-data.lua`, selection/revocation/cleanup and configuration entry points. Cover settings paste, build/revive/clone, actual removal, mark/cancel distinction, force/surface changes, power transitions, owner release and backpressure recovery. Verify invalidation arriving during refused work or partitioning is not lost, unaffected fronts/identities survive, latest accepted state eventually presents, and canceled objects retire without another guest write.
- [ ] 2.4 Update `docs/player/api/monitor.md` and `docs/player/monitor-animation.md` for unchanged synchronous APIs, demand-driven presentation, residual live observation and no new limits. Verify documented method arities/errors against `scripts/services/monitor.lua` and the API companion; run `python tools/test_monitor_animation.py` and `python tools/planning_examples.py --check`. Rerun the focused production-tick fixture after the end-to-end changes; do not call a stopped-program-only optimization complete.

## 3. Preserve authority, accounting and durable work

- [ ] 3.1 Extend existing component, budget and shell contracts to cover fresh same-event proofs, idle Console selected-path revocation, temporary proof blockage, exact wire binding, removal/replacement during queued work, and repeated selection/topology churn. Verify no stale publication, false detach, replacement targeting, retained work growth, starvation, credit renewal or increased capacity; keep direct native probes distinct from actual-tick scheduling assertions.
- [ ] 3.2 Add compatible versioned bookkeeping and synchronized one-time enrollment in existing registry/lifecycle/presentation paths. Extend `tests/monitor_state_engine.lua` and its existing wrappers, plus the focused fixture where needed, for idle, partially participating, pending, preparing, ready-deferred and retiring cold boundaries. Verify separate-process reload preserves exact fronts/models/ownership/progress/credits without source replay, load-time mutation or unnecessary idle redraw; malformed/unknown state remains recoverable and cannot authorize service.
- [ ] 3.3 Extend `tools/monitor_upgrade.py` and `tests/monitor_upgrade_engine.lua` with an explicit immutable 0.1.16→candidate case while preserving the existing 0.1.4 historical path. Verify real old/new version markers, correct matching engine/data, both content modes, settled and unfinished work, then an ordinary cold reload. Confirm valid unchanged fronts/identities survive and enrollment is not repeated on stable ticks; do not substitute a renamed ZIP for a versioned upgrade.
- [ ] 3.4 Document the scheduling-state migration, supported rollback procedure and retained-state guarantees in `docs/player/monitor-animation.md`. Verify all cold/upgrade receipts against the exact tested archives and reconcile the documentation with actual behavior; keep any historical-only engine/client evidence explicitly labeled.

## 4. Verify the final package end to end

- [ ] 4.1 Build the final candidate and run the affected packaged monitor, lifecycle, shell, notification and authority fixtures in both content modes, including production-context cold states and the new structural fixture. Run both existing four-walls and mixed animation gates with unchanged examples, cadence and budgets, plus relevant contention/fairness checks. Verify every required receipt, normal process exit and archive hash; rerun affected gates if production bytes subsequently change.
- [ ] 4.2 Run baseline/candidate timing windows serially on the same host for the zero-monitor control, 144 idle tiles, one updating independent screen and all four continuously updating screens, including sparse/full-row submission and repeated cold windows. Use a pre-change comparison too when its payloads differ from 0.1.16. Verify exact samples, live workload, whole-scheduler mean/median/p95/max and separate phase attribution; report gains, residual costs, regressions and host contention without inventing a numerical pass/fail threshold.
- [ ] 4.3 Exercise actual 2.1.23 client appearance/input and connected-multiplayer determinism for the affected behavior: idle/native blink, active coherent output, outage/restoration, marking/cancel/removal, non-anchor touch, cold recovery and joining peers. Inspect actual captures/state receipts and clean exits. If matching licensed client/data or peers are unavailable, record the blocker and leave this task incomplete; headless assertions and 2.0.77 history do not substitute.
- [ ] 4.4 Write the proposed `docs/monitor-maintenance-validation.md` and this change's `verification.md` with scenario-to-fixture mapping, exact package/source/engine provenance, structural results, complete timing distributions and explicit graphical/multiplayer status. Preserve raw selected evidence outside git and expiring scratch. Verify every acceptance claim against its receipt, all implementation tasks against their actual outcomes, `openspec validate demand-driven-monitor-maintenance --strict`, planning-example checks and `git diff --check` before handoff.

## Verification command reference

These are implementation-time commands, not checks executed while writing this plan. Set `FACTORIO` to the matching 2.1.23 headless executable after verifying its `--version` and `--help`. Use a fresh `$WORK` under `$TMPDIR`, outside the repository, and an archive built from the actual candidate. Do not substitute the older 2.0.77 executable named in historical local instructions.

Existing supported focused checks:

```sh
python tools/build.py --output "$WORK/package" > "$WORK/build.json"
ARCHIVE=$(jq -er .path "$WORK/build.json")
python tools/smoke.py --factorio "$FACTORIO" --archive "$ARCHIVE" \
  --output "$WORK/components" --mode both --fixture tests.monitor_component_contract --cold
python tools/monitor_animation.py --factorio "$FACTORIO" --archive "$ARCHIVE" \
  --output "$WORK/animation-four" --mode both --layout four-walls
python tools/monitor_animation.py --factorio "$FACTORIO" --archive "$ARCHIVE" \
  --output "$WORK/animation-mixed" --mode both --layout mixed
python tools/monitor_performance.py --factorio "$FACTORIO" --archive "$ARCHIVE" \
  --output "$WORK/performance-sparse" --mode both --layout four-walls \
  --workload sparse --ticks 3600 --max-gap 2
```

Run each sustained case separately and serially with fresh output paths. Repeat the performance command for the immutable baseline and `--workload full-blit`; use the scene options introduced and documented by task 1.3 for zero/idle/one-screen cases rather than pretending those options already exist. Derive the broader contract/production-context fixture matrix from `.github/workflows/ci.yml` and the smoke allowlist; do not apply `--production-context` to unsupported fixtures.

Proposed new-fixture invocation, valid only after task 1.2 registers it:

```sh
python tools/smoke.py --factorio "$FACTORIO" --archive "$ARCHIVE" \
  --output "$WORK/demand" --mode both --fixture tests.monitor_demand_engine \
  --production-context --cold
```

## Workflow follow-up

- Implementation requires a new `/openspec-apply-change` request. This proposal does not authorize applying code, publishing or merging a release.
- Keep later commits/review/PR actions scoped to authorized work. Synchronize canonical specs and archive only through the later requested OpenSpec workflow; do not hand-edit generated OpenWiki.
