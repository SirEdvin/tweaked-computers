# Consolidated acceptance and canonical contracts

## Scope and evidence identity

SC4 integrates SC1 `783401cf1a4e37c5626149b46dad01662cabbfb2`, SC2
`3a50d79f3a21b47b66f9d030e1e98f5e388cd4ea` and SC3
`99ba215d099e15f56fcab9eff5ab5637d33c13fb` with accepted main
`4fe09733d5a30fa5bbf4ad08af71ae9fa60bc941`, preserving actual merge ancestry.
The first SC4 checkpoint `bbf681e7d262684e9c51d7607e12d78c42b556c5`
rebuilds the exact SC3 archive:
`0335748c7dd51a55e5d2e97a4fd2c00194f4096b1167cd017417b87779aa1940`.
Its 303-file production/art payload digest is
`b4fe00db6d567600f3b4315a8dc03f35aeca0d090597f68e0071f2b9e91bedaa`.

Promotion changes contracts, documentation and host tooling. The sole production
payload exception is the in-game Reference path in `scripts/ui/help.lua`:
`openspec/changes/add-native-circuit-computers/api and specs` becomes
`openspec/api and openspec/specs`. The surrounding Lua bytes and all other 302
production/art entries remain identical. No executable behavior, prototypes,
localization, artwork, parser bytes, guest examples or safety budgets change.
The final ZIP necessarily has a new hash because its documentation and canonical
contract paths differ. It is not the historical public 0.1.9 ZIP and does not
replace that release. Exact final source, archive hash, per-entry correspondence,
commands, exit codes and hosted check identity are in the durable SC4 receipt:

`/home/siredvin/artifacts/tweaked-computers/t_67607dce/final/receipt.json`

The earlier read-only `handoff-audit.json` preserves the original 20 upstream row
receipts and 3,300 rehashed evidence files. Its "pre-promotion" label is historical,
not a substitute for the final receipt. The 21st row is native-computers 7.3.
No screenshot, successful startup or stale checkbox alone closes a gate.

## Row 7.3 evidence matrix

| Gate | Applicable evidence and limits |
| --- | --- |
| Exact archive, base and Space Age | SC3's exact-archive hosted matrix: 67 mode cases, 106 cold/upgrade phases and 38 summary files. Commands, markers and zero exits are retained; final promotion adds a focused local packaged matrix and exact-head hosted Mod validation on final bytes. |
| Ordinary cold load | SC1's waiting/preparing/ready/retiring buffered states plus SC2 factory/monitor peers and SC3 sustained representative factory. Identity, old visible/model state, paid progress, spent credits and once-only effects survive without on-load execution. |
| Upgrade and recovery | Retained released-monitor upgrade and ordinary-reload phases, populated old-shell migration, lifecycle/editor recovery, and Recipe Searcher installation/configuration phases. Genuine configuration changes are separate from ordinary cold loads; maximum retained content and refusal atomicity remain checked. |
| Actual editing and factory effects | SC2 native typing and clipboard paste, Validate/Save/Run/Apply/Stop, draft conflicts, exact active/saved source and actual inserter movement/cessation. Reset/rejection edge cases remain labelled engine/model evidence, not invented native clicks. |
| Actual touch and visuals | SC2 base/Space Age cardinal physical/wire campaign, dense/nonsquare/maximum displays, native mark/cancel overlays, actual two-player touches, GUI-hover refusal and current chart recordings. Native windows/video were inspected by the owning campaign; SC4 also inspects retained representative windows. |
| Connected joining and determinism | SC2 uses one localhost server and two real licensed clients in each mode, fresh/late joining and separate ordinary-cold processes, for both factory and monitor cases. All three processes agree on retained state, sequences, ownership and effects. No headless-only or mocked substitute is used. |
| Combined supported envelope | SC3 user-approved representative factory: four useful guests, four subscriptions, native targets, KV and selected 3×2+1×1 displays for 577 ticks/mode across cold reload. All 23 changes reach 92 subscriber deliveries and 23 coherent publications. This is not simultaneous independent-cap saturation. |

Per-row commands, fixture names, engine mode/phase, inspected capture paths,
archive/payload comparisons and limitations remain in these durable receipts:

- SC1: `/home/siredvin/artifacts/tweaked-computers/t_da5b8be7/receipt.json`.
- SC2: `/home/siredvin/artifacts/tweaked-computers/t_febbc243/final/receipt.json`.
- SC3: `/home/siredvin/artifacts/tweaked-computers/t_a3385898/resumed-2026-10-19/receipt.json`.

[SC2 detail](sc2-native-acceptance.md) and [SC3 detail](sc3-supported-envelope.md)
retain historical failures, finite counts, source correspondence and interpretation.
The earlier maximum-world sampler failure and unfavorable CPU/tail observations
are preserved, not erased by the approved representative scope. Normal shutdown
means acknowledged server `/quit` or normal client close, zero exit and no forced
cleanup; failed attempts remain separate from passing cases.

## Console and Recipe Searcher applicability

The original Console candidate is SHA-256
`56dac45fd33be1f79eb6e3e750250cce09ee890266c9d7f39c4a7e60ecdff501`;
Recipe Searcher is
`cc65adb0074e214609b78a8507ece323952ca276734411de6e67f19e56ebbdb9`.
Their original receipts are retained under `t_dd7ab003/accepted-candidate/audit.json`
and `t_35655795/rs1/verification-report.json` respectively.

SC4 compares the actual intervening production paths rather than assuming whole
archive equality. Shell/compiler/scheduler/serialization/service ownership code
is unchanged. Later additions register Recipe Searcher, its independent research
and art, normalize only displayed Console tabs, update logic input/category
semantics, allow native Ctrl actions, forward guarded body rotations, and expand
strictly opt-in fixture hooks. Current shell contract/cold, GUI workspace, lifecycle,
logic and recipe fixtures cover the affected integrations. SC2 supplies current
native opening/input/rotation and connected factory/display coverage. The Console
snapshot normalization preserves raw logs, tuple arity, newlines and byte bounds.
The final Reference-path correction changes only documentation text, and is
explicitly compared rather than hidden inside a claim of whole-payload equality.
The searcher provider, exported schema, research ownership and its own PNGs are
unchanged from its accepted candidate; the monitor stack-size change does not
alter search queries or its physical sprite.

Thus original native/peer receipts remain applicable to those unchanged feature
paths, supplemented by current-archive regressions; they are not represented as
new native campaigns on the promoted ZIP. Console and searcher original connected
late-join campaigns are base-only; SC2's broader factory/monitor peer matrix covers
both engine modes. No claim is made that shell-specific late joining was newly
exercised in Space Age. History remains removed by explicit user approval.

## Promotion and reproducibility

The user approved "sync now" for all five changes on 2026-10-19. Current CLI
status/rule snapshots are retained under SC4 `approved-sync/`. Baseline specs are
established first; redesign modifications preserve baseline scenarios; buffering
extends those results; Console and Recipe Searcher add their capabilities.
Canonical specs preserve authored Purpose sections and all original scenarios.
Console-only globals/durable symbolic bindings are explicit exceptions, not a
relaxation of saved-handler syntax, ordinary Data or no-function persistence.

Canonical contracts live in `openspec/specs/` and `openspec/api/`. The full terminal
API and buffered-presentation companion are both shipped. Historical planning,
API companions and schema declarations remain under the five dated archives;
packages exclude archive/proposal/design/task history. `tools/build.py` has a
28-file explicit contract inventory. Package tests check canonical completeness,
link destinations, baseline Purpose and requirement/scenario conservation.

Strict OpenSpec, deterministic packaging, generated catalogue/examples, strict
MkDocs/built links and the final packaged regressions are recorded individually
in the final receipt. The PR must have the exact-head Mod validation check from
integration 15368 under the live strict main ruleset; an older parent/merge-candidate
check is not substituted. This is a review handoff, not permission to merge,
release, bump versions, publish, deploy or adopt new artwork.

## Interpretation

All native evidence uses Factorio 2.0.77 build 84539 and isolated player data.
OpenGL llvmpipe validates finite appearance observations, not representative GPU
FPS or universally smooth 60 UPS. Two-tick headless publications and recording
frame rates are not client FPS. Work-unit ceilings remain provisional safety
limits; independent maxima are not a simultaneous-capacity promise. Automated
acceptance is not user manual/aesthetic approval, arbitrary-modpack coverage or
WAN/network-condition certification. No production budget or 256-tick target was
raised or weakened. Separate artwork alternatives remain outside this promotion.
