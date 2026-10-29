# Production Statistics verification

This is the implementation evidence map for `add-production-statistics-peripheral`,
not a release announcement, engine port or archive operation. The source mod version
remains **0.1.16**. The target is exactly **Factorio 2.1.23 (build 87750)**, base and
optional Space Age. All game processes use isolated write/config/mod/save trees and
the campaign's shared `factorio.lock`; licensed distributions and player data are
never modified by the fixtures.

## Exact identities and receipts

The durable evidence home is
`/home/siredvin/artifacts/tweaked-computers/openspec-campaign-2026-10-27-3b5667a/t_befacf89/`.
Its `final/` inventory and `checklist-ledger.json` bind the reviewed source revision,
per-file SHA256s, exact tested ZIP SHA256, engine/content modes, commands, expected
case inventory, native process phases, completion markers, normal exits and selected
captures. `publication.json` separately binds the eventual feature PR and literal
head CI; local tests do not imply hosted CI success. Historical attempts remain
separate and cannot be counted as passes for changed bytes.

The parent implementation is SirEdvin/tweaked-computers PR #47 at
`adc01ab16eaf014eab26618e8bde1a58cb865849`, descended from the approved campaign
baseline `3b5667a6e4868b99b6123a16a83abe5e551602cb`. Its code is included by ancestry,
not cherry-picked or represented as newly implemented statistics behavior.

## Checklist-to-evidence map

| Row | Required evidence |
| --- | --- |
| 1.1 | Initial packaged missing-device failure; `production_statistics_data` geometry/contact/power/recipe/stack/research checks in both modes; native lifecycle scene |
| 1.2 | `assets/check.py`, exact pre-existing PNG comparison, eight-family cardinal/contact/icon sheets and all 256 status frames; native appearance is a separate gate |
| 1.3 | Fresh shared unlock, `production_statistics_upgrade_engine` immutable old-save installation, ordinary cold and later reconciliation; lifecycle mining/clone/rotated wired blueprint/helper cleanup |
| 2.1 | Immutable pre-feature missing-method guest regression; exact four-method inventory, complete native totals/qualities/directions, mutation isolation and defensive limits |
| 2.2 | Every supported precision, each of all 300 native samples in both directions, native reset/current-tick merging, zero/fractional/modded identities and real pollution source/sink maps; normal/legendary item queries |
| 2.3 | Two forces/two surfaces, native pollution sharing, explicit color/path isolation, unpowered limits, revoked captured methods, native clone/remove surface moves, real work/allocation pressure and 1,030-distinct-item whole-result refusal |
| 3.1 | Inspector/editor/help inventories, powered/unpowered identity/name selection, stale/foreign authority and provider spies proving inspection performs no statistics query; actual native copy/open/close |
| 3.2 | Exact shared Reference/packaged source, empty versus refusal branches, all categories/operations and the unchanged monitor API drawing both historical directions oldest-left; actual client captures |
| 3.3 | Canonical capability/API union (including parent Factoriopedia inspection), explicit package/docs inventories, deterministic builds, planning examples and strict rendered documentation/link checks |
| 4.1 | Both-mode production-context statistics and large-result cold fixtures, integration, lifecycle, API inventory, inspector, Reference, art, Recipe Searcher, parent Factoriopedia, runtime and redesign checks; previous-release installation |
| 4.2 | Matching complete licensed clients, native Items/Fluids/Pollution charts at controlled ticks, qualities, counts/rates/sample direction, all rotations/contacts, status/name copy and Reference/monitor workflow screenshots |
| 4.3 | A real localhost server plus two independent full clients in each mode, actual late join, cold restart, equal independently written observations, unchanged boot count, stale binding refusal, no desync evidence and clean exits |
| 4.4 | Matched control/idle/polling real-tick scenes with unchanged production budgets and active neighbors; exact sample counts/credit consumption, separate native-call and scheduler timing, source audit excluding a new collector/cache/history job |
| 4.5 | Full receipt inventory reconciled to every checkbox, strict change validation, whitespace/package/generated/docs/art checks, committed/pushed feature branch and successful required literal-head CI |

A row is complete only when its whole evidence set exists. A creation-only
`passed=true` summary never substitutes for scheduled/cold assertions. The final
machine-readable ledger, rather than this list of required proofs, records the
actual passing phase inventory and hashes.

## Native query and resource fixtures

`tests.production_statistics_engine` uses real engine statistics and compiled guest
calls through the production provider/facade/Data boundary. It compares exact map
keys and values, with no sorting/normalization/union, and every native sample rather
than an abbreviated series. Real `tile-proxy` and `tree-proxy` pollution sinks are
queried as recorded native identities. The other test surface uses spores with
Space Age. Its separate-process boundary retains identities, wires, copied snapshots
and spent same-tick credits; fresh queries after reload use current native objects.

`tests.production_statistics_large_engine` adds 1,030 real distinct item prototypes
and recorded keys. Totals/rates must refuse completely under existing Data rules,
while the representative single-entry history remains independently accessible.
No budget is raised. Work/allocation exhaustion is tested through the actual
compiler/guard, including an attempted `pcall` escape; no partial result or retained
query job is accepted. `production_statistics_contract` labels host doubles only
for inaccessible native exception/nonfinite injection.

`tests.production_statistics_timing_engine` compares 32 idle KV controls with 32
idle statistics instruments, then polls a separate powered statistics device with
two neighboring active computers. It excludes population/startup using 60-tick
warm-up windows and records exactly 120 scheduler samples per phase. Native
600-call history profiling is separate from scheduler profiling and deterministic
work/allocation counters. The cold receipt validates the retained sample inventory.
These are observations, not a numerical performance threshold or hard C++ bound.

## Client and connected-peer boundaries

The client fixture uses controlled native flow inputs, not synthesized history.
Guest observations cover complete native totals/rates and all history samples;
real native chart controls supply the independent graphical comparison. Native UI
rounding and incomplete/current-tick sample boundaries are not API conversions.
Actual-window/UI captures are distinct from `game.take_screenshot` world captures.
The monitor runs the exact maintained source with no private second history.

The connected gate launches its first full client before freezing an agreed retained
snapshot, launches the second afterward, and resumes through synchronized join
handling. The server and each client write their own observations. Comparisons use
the live agreed snapshots before disconnect, not shutdown-rewritten peer membership.
The cold phase restores that saved world in another server process and repeats
connected observations. Independent headless processes are not multiplayer evidence.

## Approved visual comparison: native GUI smoothing

At the original checkpoint acceptance was incomplete. In the base 2.1.23 client at tick
271, candidate 8 (`d33b1ba296ee8ca1020debaacbb61beb7b0d30ae1a4c8035dcf2f9c9c22ba4ce`)
returned exact native histories but the one-minute vanilla fluid graph had a peak
label of **413**, versus the raw water sample peak of **1800**. All 300 samples on
each side had already been compared directly with the native getter by the fixture.
The native bottom-row rate was 60.5/minute, matching `getRates`; this is a graph
presentation difference, not a bulk-rate discrepancy.

Factorio developer Twinsen's May 30, 2019 explanation documents a native sliding
window of `1 + floor(150 / sqrt(window_ticks / 300))` samples (official forum post
`https://forums.factorio.com/viewtopic.php?p=433048`). Applying that documented
presentation to the captured one-minute history gives a 44-sample window and peak
412.5, consistent with the observed rounded GUI label. This is evidence about the
observed 2.1.23 presentation, not a promise that every future engine uses that formula.

On October 28, 2026, the user explicitly approved accounting for pinned-engine GUI
presentation smoothing, in addition to rounding and documented sample boundaries.
This supersedes the earlier decision request in the immutable checkpoint, not its
observations or remaining acceptance gates. No API smoothing, relaxed resource
limits, constant-flow replacement fixture or waived client gate is authorized.
The original burst and its mismatch remain preserved; each controlled comparison
must prove its own observed values, with all 300 raw samples per side exact.

Candidate 8's incomplete matrix and paused-inspector captures remain historical
failed/partial evidence in the immutable checkpoint, not acceptance receipts.
Candidate 10 subsequently passed the statistics, large-result, timing, lifecycle,
integration, inspector, Reference and help cases in both modes. Its editor run
exposed a second closed-search assertion: searching Recipe Searcher now correctly
matches the statistics topic too, because both share its unlock. The focused fix
asserts the exact two matching family titles; it does not change filtering behavior
or remove the original Recipe Searcher content check. The final matrix must rerun
that fixture and all named remaining cases; only its reconciled ledger counts.
Candidate 11 then reached the runtime fixture's obsolete ten-example assertion;
the additive statistics planning example makes eleven. Its fix preserves compilation
of every source and updates the exact inventory/marker, with the failed run retained.

The resumed native clients independently verified exact totals/rates and 300 raw
samples per side, powered/unpowered normal inspectors and native Select name /
Ctrl+C / Ctrl+V identity acknowledgements, Reference topic/tutorial navigation,
all four wired cardinal views, and the maintained monitor drawing native history.
At frozen tick 961 in each content mode, the one-minute burst has raw input peaks
7200 (normal iron), 1800 (water) and 450 (furnace pollution). Verification-only
44-sample smoothing predicts 1650, 412.5 and 103.125, matching native graph labels
1.7k, 413 and 103. The consumed copper and Space Age legendary iron each have raw
peak 3600 and displayed peak 825; legendary selection shows its separate 121 total
and 121/minute, versus normal iron's 242. The zero opposite-side histories remain
zero. Rates 60.5 water, 30.25 steam and 15.125 pollution agree with GUI rounding.
These observations do not transform the runtime API.

Fresh and cold connected runs in each mode use a localhost-only server and two
independent complete clients. All three peers independently write identical live
observations, with boots exactly once, full map/sample parity, changed device
identity and a refused stale captured method, including after cold reconstruction.
Their normal-exit and desync inventories are separate from the headless matrix.
Final package/source hashes, affected reruns, exact check IDs and actual completion
status live in the durable ledger/publication receipt, not a prospective claim here.

## Upgrade, failures and limitations

The immutable pre-feature archive is SHA256
`95fa7ef48ade7d1494a2f00ccb1ef75a943a87f92699205106ade6ad772ce826`.
The shared installation harness instruments only its allowlisted test hook/module
and proves all other payloads identical. Upgrade candidates differ from the tested
feature only in the test-only ZIP prefix/version, `info.json` version and corresponding
package-manifest metadata. These copies never mutate the old release or source version.
Already-researched Recipe Searcher forces unlock statistics; Circuit-Computers-only
forces remain locked, with old entities/source/data/wires preserved. Rollback means
restoring the pre-upgrade save and matching archive, not downgrading a new save.

Preserved failures include the intended missing device/method regressions, a test
scene using an undersized monitor, an attempted unsupported cross-surface teleport
of a static combinator, and an observational fixture discarding a required native
return value. The corrected tests use the documented joined display, native
clone/remove movement and consumed native results. None changes production budgets,
authority or the complete-or-error API.

Xvfb/llvmpipe validates appearance, not representative GPU FPS/UPS. Native profiling
is separate from GUI capture overhead; unrelated host contention is not controlled.
Fixed native-call admission plus actual Lua work/result accounting does not bound
opaque C++ getter allocation or wall time. No collector, retained native handles,
query cache, asynchronous API, capacity setting or runtime rewrite was added.
No merge, OpenSpec archive, source version bump or release publication belongs to
this implementation handoff.
