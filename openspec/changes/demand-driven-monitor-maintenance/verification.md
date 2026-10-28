# Implementation verification: demand-driven-monitor-maintenance

## Scope and source

- Campaign baseline: `3b5667a6e4868b99b6123a16a83abe5e551602cb`.
- Owned branch: `campaign/0.1.17-demand-driven-monitor-maintenance`.
- Destination: `SirEdvin/tweaked-computers:main`; no parent implementation PRs.
- Engine/data: Factorio **2.1.23 build 87750**, headless and licensed full clients,
  explicit base-only and Space Age bundled-mod lists.
- Source release version remains **0.1.16**. Upgrade alone uses an isolated,
  explicitly versioned metadata-only 0.1.17 package. No release is published.
- Canonical synchronization/archive and main merge are downstream work. This
  feature's delta/API companion do not replace neighboring canonical content.

The detailed behavior, measurement method, limitations and complete timing
appendix are in [monitor maintenance validation](../../../docs/monitor-maintenance-validation.md).
The durable root below contains the exact package and source hashes, command
inventories, process-phase receipts and selected visual/native evidence:

```text
/home/siredvin/artifacts/tweaked-computers/
  openspec-campaign-2026-10-27-3b5667a/t_48587211/
```

## Checklist-to-evidence ledger

A checkbox is completed only after its entire row is verified. Original failed
runs remain separate from the selected passing receipt inventory.

| Row | Evidence and assertions |
| --- | --- |
| 1.1 | `baselines/provenance.json`, immutable released/pre-change ZIPs, release lookup, engine/client preflight. Full payload comparison identifies documentation/manifest differences only. |
| 1.2 | Baseline structural red; focused observer and private boundary instrumentation; final `demand` summary: six stages × eight samples × both modes, live 144-tile and producer checks, physical-change tail. |
| 1.3 | Performance harness regression red/green; host invocation/provenance inventory tests; serial baseline scenes, frozen source/example hashes and matched comparison windows. |
| 2.1 | Structural counters; same-event component authority; stopped native outage/restoration; silent move/rotation/force/surface-clone/helper tail; lifecycle/integration/network/rotation/art neighboring-device fixtures. |
| 2.2 | Snapshot/budget/optimization/presentation contracts; burst/no-op/error/immutable preparation checks; one-screen unchanged-front assertions; unchanged four-screen chart and contention gates. |
| 2.3 | Component settings-paste regression and resize fix; lifecycle/native clone/build/remove paths; actual mark/cancel/mining; ownership release, blocked/refused work and state fixtures; pending topology observation guard is test-only. |
| 2.4 | Player API/animation documentation; unchanged service signatures and API companion; planning-example and animation host checks; final active+idle structural fixture. |
| 3.1 | Extended component/budget/shell contracts; exact same-event wire/authority checks, temporary blockage, idle Console revocation and bounded churn; actual scheduler and cold cases kept distinct from direct native probes. |
| 3.2 | Six production-owner cold wrappers: idle, waiting, pending, preparing, ready and retiring. Saved graph/aliases/native visibility, source effects, spent credits and unsupported/malformed container refusal retained. |
| 3.3 | `upgrade-0.1.16` and historical `upgrade-0.1.4`: two content modes, real old/new versions, configuration-change and ordinary cold processes, valid fronts/identity and unfinished progress. |
| 3.4 | Player save compatibility/rollback section reconciled with old/new archives and exact cold/upgrade receipts; 2.0.77 applies only to historical old-save creation. |
| 4.1 | Explicit 30-case affected matrix, both modes; exact smoke phase success/clean exits, demand counters, four-walls/mixed animation, modem/speaker contention and both upgrades. Evidence spans byte-compared candidates; it is not relabeled as one complete later-package run. |
| 4.2 | Two independent 15-case whole-scheduler matrices × both modes, 600 samples each; separate 15-case phase attribution. Exact guest/test-payload comparisons and live workload checks; full mean/median/p95/max tables, residual costs/regressions and host contention disclosed. |
| 4.3 | Actual 2.1.23 dense clients plus server/two-client fresh+cold matrix in both modes: 28 native driver checks each, exact three-engine state, normal shutdown and desync checks. Actual captures and sampled recordings inspected separately, including zoomed stopped native blink. |
| 4.4 | Detailed report, complete generated timing appendix, verified ledger and byte-preserved external bundles; strict OpenSpec, planning/generated/docs/art checks, package inventory and diff checks; owned PR and literal-head required validation recorded in publication receipt. |

## Reproduction and receipt interpretation

Use the repository's documented build, smoke, animation, performance, demand and
upgrade wrappers. Every output directory must be fresh under `TMPDIR`. Serialize
all engine/client processes using the campaign's `factorio.lock`; never reuse a
player save, source symlink or licensed distribution's write directory. Host-only
unit tests do not prove native behavior. `--cold` must reach both runtime phases:
a creation-only `passed: true` receipt is insufficient.

`verified-ledger.json` enumerates the selected cases and validates mode counts,
archive identity, process results, cold markers and normal cleanup. It separately
records payload equivalence between the behavioral packages. The final package
receipt records any later documentation/manifest-only differences; source/package
hashes and the published Git commit are not interchangeable identities.

## Retained failures and limitations

- The immutable release's unchanged tick performs real redundant topology/full
  proof work, and its settings-paste path omits the required scale resize event.
  Those failures are preserved, not converted to candidate passes.
- Early observer-import, unsupported native teleport and guessed host-command
  invocations are setup failures, not native acceptance. The corrected physical
  surface case uses clone/retirement and does not claim same-body teleport.
- A misconfigured graphical pilot used the wrong write-data placeholder. It is
  quarantined and excluded. All selected client paths are checked against actual
  logs, not only requested command arguments.
- Two older direct/private mutation fixtures needed explicit existing wakeups;
  their original assertions remain. No production budgets or timing thresholds
  were raised to obtain a pass.
- The overview/benchmark cursor clips were visually inconclusive because of
  subpixel geometry/native hover. An ordinary live-client scale-2 closeup with
  hover moved away visibly switches its underline in both modes, preserves
  unchanged glyphs/fronts and asserts 701 settled ticks without presentation work.
  It supplements, rather than reduces, the full-density and native-peer gates.
- Xvfb uses software rendering; timing is diagnostic whole-scheduler CPU on a
  shared host, not hardware GPU FPS, arbitrary modpack performance or zero idle
  overhead. Localhost connected-peer acceptance is not all network conditions.

Review, merge, canonical union synchronization, archive and next-patch release
remain the downstream campaign's responsibilities.
