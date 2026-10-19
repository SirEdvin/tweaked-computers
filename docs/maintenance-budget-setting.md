# Maintenance budget setting: MB1 implementation and verification

Player instructions and supported combinations are in [Common effective limits](player/api/limits.md#maintenance-and-shared-headroom).
This change exposes the existing provisional allowance; it does not select a new
performance default, redesign sampling, or raise any other default.

## Contract and implementation inventory

- `scripts/runtime/limits.lua`: default remains 200000, inside the unchanged
  default shared host envelope of 5000000.
- `scripts/runtime/budget-settings.lua` and `settings.lua`: the existing shared
  runtime-global prototype/refresh pipeline adds `tc-maintenance-work-per-tick`.
  Requests support 200000–100000000; effective maintenance is
  `min(requested, host_work_per_tick - 1)`. The host setting itself never changes.
- `locale/en/settings.cfg`: localized Map setting name, scope, trade-offs and
  supported bounds. `computer.getLimits()` uses its existing defensive effective
  limits copy, not the requested settings value when clamped.
- `scripts/scheduler.lua`: maintenance admission reads live ceilings even through
  an already captured spender. Retained spent-credit validation uses the supported
  hard maximum rather than the current setting, so a decrease does not invalidate
  a legitimate old ledger. An exhausted scheduler-entry identity walk defers
  without throwing or resetting counters, but still runs the existing fail-closed
  sampler refusal path so a signal-observation tick cannot silently disappear.
- `scripts/runtime/admission.lua`: guest reservation and cached charge replay
  account for the greater of current maintenance reservation and maintenance
  actually spent that tick. Program and shell scheduling use the same headroom.
  Headroom clips at zero after a host decrease below prior spending; untouched
  callbacks defer rather than faulting merely because that tick has no headroom.
- The admission ledger retains an alias to the authoritative scheduler table,
  not a duplicate spent counter. Old saves attach the missing alias only during
  synchronized maintenance admission. Parsing/refresh only rebuilds ephemeral
  effective limits; no world mutation or guest execution occurs in `on_load`.
- `scripts/rendering.lua`, `scripts/monitor-presentation.lua` and
  `scripts/monitor-model.lua`: unchanged 60000 baseline / at-most-160000 adaptive
  reservations and independent 160000 whole-commit ceiling. Reservation decisions
  stay frozen for the current tick. Larger maintenance does not increase cell,
  object, topology, guest or commit capacities.
- `tools/build.py` already packages settings, runtime, localization, docs and
  fixtures with exact per-file hashes; its common limits inventory still records
  defaults. `tools/test_build.py` additionally checks exact packaged settings,
  localization, budget fixture and player-limit documentation bytes.

The lower bound deliberately preserves the existing baseline non-render service
opportunity of 140000 units (40000 on boosted ticks). This is a conservative
supported floor, not a measured proof that every smaller value fails. Lowering
it requires a separate atomic topology/render feasibility decision; MB2 must
report unsupported lower candidates instead of bypassing prototype validation.
The upper bound follows the configurable-work safety envelope, not a CPU target.
Very high requested maintenance at a small host setting can leave only one guest
unit: it is safe accounting, not a usable program configuration or recommendation.

## Live changes and persistence

Neither ledger is replaced by a setting change. Spending above a newly lowered
ceiling remains valid, but further charged work refuses until a sufficient
increase or a new simulation tick. Maintenance increases also respect guest
spending already committed under the previous split. Reducing host work below
combined spending cannot undo earlier effects, but admits no further work beyond
the new ceiling. No paid reconciliation, reset, or on-load migration is needed.

`tests.runtime_budget_engine` uses real `LuaSettings` writes in the owning mod
context and invokes the exact registered production settings handler with its
engine-shaped payload. This verifies refresh integration, not native settings-GUI
event delivery. It covers captured spend callbacks, increases/decreases, minimum
and maximum requests, host clamping, shared spending in both directions, warm
charge replay, zero guest headroom, unchanged render bounds and defensive guest
readback. Its scheduler-entry sampling-refusal registration is table-backed;
`tests.logic_engine` separately checks native subscription/output cleanup. Its
explicit-clock boundary checks are not production latency samples.

The fixture saves genuinely spent guest credits and 300000 maintenance units
with the setting lowered to 250000. Separate server processes verify the saved
alias, counters, reservation and retained state during load, old-tick refusal,
exactly one additional credit after a sufficient increase, and later real-tick
recovery. It then runs a real compiled callback through production scheduler ticks
with live 400000/250000 changes, checking active-program and state identities.
Both phases require acknowledged console `/quit`, no signals or forced cleanup.

The existing renderer fairness regression retains its near-maximum path witness
as a separate focused compatibility check; it is not a required representative
combined-load benchmark. MB2 owns measured workload/default recommendations.
Headless correctness is not native GUI, connected multiplayer or GPU/FPS evidence.

## Reproduce focused checks

Use a fresh output directory outside git and the pinned 2.0.77 engine:

```sh
HEADLESS=/home/siredvin/tools/factorio/bin/x64/factorio
WORK=$(mktemp -d "${TMPDIR:?}/tc-maintenance-XXXXXX")
python tools/test_build.py > "$WORK/package-tests.log" 2>&1
python tools/player_docs.py --check --report "$WORK/player-docs.json"
python tools/build.py --output "$WORK/package" > "$WORK/build.json"
ARCHIVE=$(jq -er .path "$WORK/build.json")
python tools/smoke.py --factorio "$HEADLESS" --archive "$ARCHIVE" \
  --output "$WORK/runtime-budgets" --mode both \
  --fixture tests.runtime_budget_engine --production-context --cold
for fixture in runtime_contract compiler_cache_contract monitor_budget_contract; do
  python tools/smoke.py --factorio "$HEADLESS" --archive "$ARCHIVE" \
    --output "$WORK/$fixture" --mode both --fixture "tests.$fixture"
done
for fixture in monitor_budget_engine monitor_presentation_engine integration_engine; do
  python tools/smoke.py --factorio "$HEADLESS" --archive "$ARCHIVE" \
    --output "$WORK/$fixture" --mode both --fixture "tests.$fixture" \
    --production-context --cold
done
```

CI already runs the expanded budget fixture in both modes with cold reload, plus
existing renderer, compiler, shell and factory regressions. No new workflow or
separate framework is introduced. Exact tested source/archive hashes, commands,
per-mode summaries, native logs and shutdown receipts are retained outside git in
`/home/siredvin/artifacts/tweaked-computers/mb1-maintenance-2026-10-19-2sT9vJ/`.
Historical/earlier candidate directories there must not be attributed to the final
archive; use its final build manifest and final matrix summaries.
