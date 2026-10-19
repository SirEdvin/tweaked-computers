# Monitor buffering: 0.1.5 alpha verification

## SC2 native-client and connected-peer acceptance (2026-10-19)

SC2 now closes the formerly deferred native visibility-swap row 1.3 and native
dense/plot/interaction/peer row 6.3. The full per-row matrix, inspected actual
windows/videos, exact source/archive/payload correspondence and external receipt
are in [SC2 native acceptance](sc2-native-acceptance.md). This is automated Linux
2.0.77 build 84539 / llvmpipe appearance and actual localhost peer evidence,
not user manual approval, hardware FPS or stable-release certification.
Historical deferral statements below retain their original scope; they are not
the current status of these two SC2 rows. The 256-tick/full-envelope/CPU gate
remains SC3 row 6.2, unchecked and unchanged. No version bump, merge, publication
or archival is performed by this acceptance campaign.

## SC1 acceptance reconciliation (2026-10-19)

The historical sections below describe their original candidates. SC1 starts at
accepted main `4fe09733d5a30fa5bbf4ad08af71ae9fa60bc941` (0.1.9), without a
version bump or a change to production budgets, renderer or service behavior.
The remaining gaps were regression coverage and evidence/checklist reconciliation,
not absent buffering. The only control change admits four opt-in test modules;
normal control registrations and all production service/renderer bytes are unchanged.

The durable receipt is
`/home/siredvin/artifacts/tweaked-computers/t_da5b8be7/receipt.json`.
It binds every assigned row to the exact source commit, deterministic candidate
archive, production-payload digest, commands, per-mode summaries and raw logs.
The external receipt avoids a self-referential archive hash in packaged docs.
The release-0.1.9 receipt at `t_a91d1885/verification-report.json` and its matrix
ledger are reused only after archive/payload comparison, not as fresh candidate
passes. Historical failures remain separate from final passes.

| Assigned row | Evidence and boundary |
| --- | --- |
| 3.1 | Existing compiled four-member/mixed-shape presentation suite plus `monitor_state_*`: strict arity/dot calls, malformed records/keys/holes/cycles/functions, exact return counts, host-only metatable refusal (guest syntax cannot construct metatables), eight refs/red preference/canonical order, current authority, actual summed-cell overflow, unpowered and foreign-surface refusal, idempotence, conflicting writers and one-unit-short admission. Refusals compare the entire retained monitor graph, table identities/aliases and native visibility. Existing player method tables/help are retained. |
| 4.1 | `monitor_state_ready` cancels an actually ready hidden cohort on cable loss (green remains connected), Stop, fault, Apply, owner removal, same-coordinate member replacement, foreign force and rotation. Old jobs never publish; accepted shared writes/fronts survive nongeometry release and automatic presentation resumes. Real partial topology preserves ownership while compiled selection refuses E_NETWORK_PENDING. The existing presentation suite covers owner/member outage/restoration, shared writers, no-op participation and explicit clear. |
| 4.2 | The ready fixture fills retirement to exactly 10,584 cells before removing all monitor tiles world-wide. Actual scheduler ticks drain every retained generation and all tracked native monitor objects within the unchanged 256-tick target. Per-tick inventory/cell/frame/object/maintenance caps remain asserted. Feedback tests inspect actual native strata and mark/cancel/robot cleanup in all four directions, and reject table-backed Ctrl-click while a real scale change leaves the visible/current grids mismatched; touch resumes at the matching published cell. These are native-object and mocked player-ingress assertions, not screenshots or native mouse delivery. |
| 4.3 | Four separate ordinary cold fixtures retain waiting mixed-size selection, hidden preparation, fully ready credit-refused commit and active retirement. Load and old-tick replay compare the entire production registry graph, exact aliases/cursors/counters and native visibility; unknown future presentation versions retain that populated graph inertly. Existing presentation cold coverage additionally retains coalesced pending vectors. The released-0.1.4 upgrade fixture saves actual unchanged 3×6/6×6 four-tile partitions, a complete unaffected image and a genuinely credit-deferred partial legacy sweep. Configuration change merges walls with surviving anchor/settings, absorbed-name detaches and content clearing/resize; complete unaffected output is adopted while partial output rebuilds. A further ordinary process verifies no repeated regroup/start or fake unaffected resize. |
| 5.3 | Existing explicit contract allowlist already ships the three buffered-monitor companions and exact example bytes, excluding planning documents. A new independent inventory assertion catches removal from that allowlist and compares deterministic ZIPs. Existing art/vendor hash validation stays unchanged. CI adds all four cold phases under existing always-retained summary/engine-log/result patterns. Strict docs and player link checks accompany the packaged matrix. |

Reproduce with fresh directories outside git:

```sh
python tools/test_build.py
python tools/planning_examples.py --check
python tools/configuration_catalog.py --check
python -m mkdocs build --strict --site-dir "$WORK/site"
python tools/player_docs.py --check --site "$WORK/site" --report "$WORK/player-docs.json"
python tools/build.py --output "$WORK/package" > "$WORK/build.json"
archive="$(jq -er .path "$WORK/build.json")"
engine=/home/siredvin/tools/factorio/bin/x64/factorio
for phase in waiting preparing ready retiring; do
  python tools/smoke.py --factorio "$engine" --archive "$archive" \
    --output "$WORK/state-$phase" --fixture "tests.monitor_state_$phase" \
    --production-context --cold --mode both
done
python tools/smoke.py --factorio "$engine" --archive "$archive" \
  --output "$WORK/feedback" --fixture tests.monitor_feedback_engine \
  --production-context --cold --mode both
python tools/monitor_upgrade.py --factorio "$engine" --archive "$archive" \
  --legacy "$LEGACY_0_1_4_ZIP" --output "$WORK/upgrade"
```

Use the locked documentation environment. The upgrade runner verifies the immutable
legacy SHA-256 before adding its opt-in fixture only to a private copy. Test credit
pressure deliberately consumes the remaining real ledger; it is not useful CPU
work or a performance measurement. Fixtures freeze after requesting a save and
resume only in the next process; every server must acknowledge console `/quit`,
exit zero and avoid forced cleanup. No client captures were produced by SC1.
Native appearance/peer acceptance belongs to SC2; full admitted-world latency/CPU
stress belongs to SC3. Neither is closed by these lifecycle checks. Keep backups
and roll back with the pre-upgrade save and matching mod ZIP, never by downgrading
an already-upgraded presentation graph in place.

## Scope and status

The 0.1.5 implementation provides automatic immutable snapshots, hidden native
preparation, whole-frame publication, every 1..6-by-1..6 tile rectangle and the
optional checked synchronized-monitor group API. The user explicitly deferred
graphical and multiplayer-client validation and authorized an alpha upload for
their own review. Those checks remain unverified (`client_verified=false`).

The historical feasibility/foundation evidence below is retained with its own
archive hashes. References there to four-tile grouping, future implementation
or an unwaived client gate describe those earlier candidates, not 0.1.5.
Native integration fixtures run actual simulation ticks; the explicit-clock
budget contract is separately labelled and is not a latency measurement.

## Release verification procedure

Use Factorio **2.0.77 headless**, both base and Space Age, and a fresh output
directory per suite. Build twice outside the checkout and compare SHA-256. Run
the exact archive through `monitor_snapshot_contract`, `monitor_budget_contract`,
`monitor_buffer_engine`, production-context `monitor_budget_engine`,
`monitor_presentation_engine`, `monitor_plot_baseline_engine`, `monitor_engine`,
production-context `monitor_feedback_engine`, `runtime_contract`,
`editor_workspace` with `candidate_data`, `editor_cold`, and production-context
`integration_engine` with `candidate_data`. All applicable persistence suites
use separate cold processes. CI retains per-mode summaries and process logs.

Run `tools/monitor_upgrade.py` against the unchanged, SHA-256-verified published
0.1.4 ZIP. Only a private legacy test copy receives the opt-in control hook and
fixture. Test unchanged 3×6/6×6 walls through configuration change and then an
ordinary cold load. Surviving anchor/settings and absorbed-name detach/resize
are checked; geometry-changing merges clear contents. An unaffected display
retains its model/cell aliases and native glyph identity without hiding it or
replaying start. Roll back using a backup save plus the matching old mod, not
an in-place downgrade of new presentation state.

The presentation fixture fills all 256 admitted tiles: four 6×6 scale-1 selected
screens, three dense maximum-resolution 6×6 singleton screens and four independent
small screens. It tests continuous writers/coalescing, final quiescence, a dense
four-member swap, one-unit-short admission with zero front/visibility changes,
overcapacity/restoration, mixed cardinal geometry, narrow strips, shared writers,
selection validation and defensive readback, no-op rounds, monitor/owner outages,
release/Stop/fault cleanup and retained earlier successful writes. Per-tick audits
compare actual retained fronts, pending, staging and retirement with their
counters, native-object caps and unchanged shared ledgers. Cold reload retains
hidden preparation plus a newer pending vector and old visible front, without
renewing credits or replaying the producer.

The plot fixture executes the exact shipped source on mixed 1×1/3×6/6×3/6×6
screens, with red/green deduplication, removal/addition, disconnect/reconnect and
resize to a tiny 2×1-character grid. A sample updates one whole row per selected
display with the same sine value before the round seals. Older rows deliberately
retain their trail: this is not a full-screen animation disguised as a speedup.
The exact historical four-row source/provenance remains separately packaged.
Its baseline fixture records producer batches, first model/publication ticks,
work/allocation peaks and scheduler CPU, not graphical speedup.

Package checks enforce intended API-companion/example bytes and unchanged
asset/vendor hashes. Strict generated documentation, built links/anchors,
OpenSpec validation and source whitespace checks accompany the engine matrix.
The immutable release's checksums and matrix summary are delivered separately
from the ZIP, avoiding a self-referential archive hash in packaged documentation.

During final regression, authentic outage/restoration exposed a stale cached
logical `powered` flag: provider availability had become true while a deferred
topology pass had not refreshed that flag. Peripheral calls now use the logical
provider's current all-member proof, rather than requiring its stale aggregate
cache too; physical providers retain their existing power checks. The retained
failed engine logs and passing outage regression distinguish this repair from
the updated legacy live-sweep fixture assumptions.

These are structural/native-object and resource tests, not graphical evidence.
CPU observations can exceed a 16.7-ms frame interval; no 60-UPS/FPS, native
tear-free appearance or multiplayer-peer guarantee is claimed. Ready-state
quiescence is distinct from waiting for producer participation or available
power/authority. The final external report binds passes to the exact ZIP hash;
earlier-candidate passes must not be attributed to later bytes.

## Historical native feasibility and foundation evidence

## Exact tested archive and commands

Private test archive, not a release or replacement of the published 0.1.4 bytes:

- Path: `/home/siredvin/.hermes/profiles/albina/cache/scratch/tc-buffer-gate-package01/tweaked-computers_0.1.4.zip`
- SHA-256: `5dd7a0c2bd01da14742addf1081002bbfa2aa435887fc11ee5eb00738398300c`
- Reports/logs: `/home/siredvin/.hermes/profiles/albina/cache/scratch/tc-buffer-gate-engine01/`

```sh
python3 tools/build.py --output "$TMPDIR/tc-buffer-gate-package01" \
  > "$TMPDIR/tc-buffer-gate-package01.json"
archive="$(jq -er '.path' "$TMPDIR/tc-buffer-gate-package01.json")"
python3 tools/smoke.py --factorio /home/siredvin/tools/factorio/bin/x64/factorio \
  --archive "$archive" --output "$TMPDIR/tc-buffer-gate-engine01" \
  --fixture tests.monitor_buffer_engine --cold --mode both
```

Use fresh output directories on a rerun. The tested archive predates this report and task-checkbox updates; its hash identifies the exact executable probe tested, not a later documentation-only rebuild.

The subsequent path-validation/reservation experiment uses:

- Archive: `/home/siredvin/.hermes/profiles/albina/cache/scratch/tc-buffer-gate-package02/tweaked-computers_0.1.4.zip`
- SHA-256: `f01a5ac2fe1ec3fa42870de00220422fe026e71e4e14e09f2a56be4e23a66ccf`
- Reports/logs: `/home/siredvin/.hermes/profiles/albina/cache/scratch/tc-buffer-gate-engine02/`
- The same build/smoke commands above with fresh `package02` and `engine02` output names; both modes and all cold process phases again passed. The backend fixture's success is not success of the separate reservation-balance gate, whose failure is explicitly logged below. This archive predates the addition of these failure notes; its executable probe bytes are the tested reference.

## Native results

Both configurations passed initial map creation, the first server's requested-save phase, and the second server's resumed-completion phase. All four server phases exited zero after acknowledged console `/quit`, without SIGINT or forced kill.

| Case | Cells per generation | Members | Old/new native objects | Charged publication units | Publication tick |
| --- | --- | --- | --- | --- | --- |
| One 6×6 at scale 0.5 | 10584 | 1 | 42340 | 127028 | 23 |
| Four 6×6 at scale 1 | 10584 | 4 | 42352 | 127088 | 68 |

These counts and ticks matched in base and Space Age. Preparation and cleanup each process at most 1024 cell slots per actual tick. Every prepared replacement background, glyph, panel and blinking cursor is created with `visible=false`; the old front remains visible throughout replacement preparation. After one prepaid publication, every member's native visibility, front pointer and presentation tick agree.

The probe's publication estimate charges three native property operations per object (validity read, visibility read, visibility write), plus eight bookkeeping units per member. It reserves that entire cost before preflight. This is an explicit provisional accounting model, not a measured CPU-time ceiling or an already adopted production cost table.

### Refusal and persistence

- With exactly one unit less than the required publication budget, repeated same-tick attempts fail without changing native visibility, front pointers, acknowledgement sequence or the already-spent ledger.
- The first case saves in that refused, fully prepared state. The resumed process verifies retained credits/native handles, refuses another attempt against the saved old tick, and publishes only after fresh actual-tick admission.
- Each case destroys obsolete objects and then tears down its retained current image in separate bounded test-cleanup phases. Native object count returns to its initial value; no probe objects leak.
- Log markers: `TC_BUFFER_REFUSAL`, `TC_BUFFER_COLD_RETAINED`, `TC_BUFFER_PRESENT`, `TC_BUFFER_BACKEND_OK`, `TC_COLD_OK`.

### Narrow CPU observations

The profiler wraps only publication reservation, preflight, visibility changes and pointer/tick updates. It excludes sprite construction, test assertions after publication, fixture setup, network-path validation, production lifecycle/scheduler work and graphical rendering.

| Configuration | Single-screen sample | Four-screen sample |
| --- | --- | --- |
| Base | 11.382938 ms | 32.537542 ms |
| Space Age | 10.975421 ms | 33.129790 ms |

These are individual ephemeral `LuaProfiler` observations, not a distribution, p95, benchmark speedup or graphical responsiveness result. In particular, the larger samples must not be described as 60-FPS acceptance. No profiler object or timing value is persisted or used for scheduling.

## Task 1.2: original measured reservation-balance failure

The second probe builds a real red NETWORK chain with 256 registered native vertices (one computer and 255 separate monitor tiles). It obtains and validates actual path witnesses of lengths 253, 254, 255 and 256 through the existing `network.discover`, `network.witness` and `network.validate_witness` functions. Native setup/teardown occurs within the same event, outside measurements, so the fixture does not leave bodies for a second mod's lifecycle owner. The endpoints are physical monitor tiles for this network-cost experiment; production six-tile grouping and logical-group registration are still unimplemented.

Both base and Space Age produced identical counters:

| Measurement | Units / result |
| --- | --- |
| Discovery, recorded as setup and excluded from commit | 5128 |
| Four current witness validations | 20296 |
| Dense four-screen native publication | 127088 |
| Witnesses plus publication | 147384 |
| Existing total maintenance ceiling | 200000 |
| Remaining non-render headroom | 52616 |
| Actual topology work charged before deferral | 49026 |
| Topology completion | false |
| Grouping job created | false |

After the real validation/publication, the probe calls the unchanged `monitor.reconcile` with the remaining authentic maintenance ledger. Its pre-partition walks fit, but its next atomic 48961-unit partition-creation charge does not. That initialization requires 97987 units even before other scheduler/lifecycle work; combined with this publication/proof cost it would require 245371, above the existing ceiling. A fixed reservation preserving the tested worst-case publication headroom therefore leaves insufficient space for this initializer. The experiment executes the topology attempt after publication to observe the remaining ledger; it is a headroom test, not a replacement production phase order or a complete factory-scheduler benchmark.

The extended four-screen profiler includes current path validation plus publication: base 41.972540 ms and Space Age 44.748972 ms. Topology's admitted prefix before refusal measured 1.311100 ms and 1.295971 ms respectively. Setup, graph teardown, assertions, other scheduler phases and graphics remain excluded. These are single observations, not latency percentiles or a general impossibility proof.

The failed gate is retained as `TC_BUFFER_GATE_BLOCKED fixed-reservation-does-not-admit-topology-initialization`, with detailed `TC_BUFFER_PATHS` and `TC_BUFFER_RESERVATION` records. Do not check task 1.2 merely because the fixture correctly reproduces this failure and exits successfully.

That failure led to a design review. The user approved demand-driven headroom and paid incremental topology initialization; the implemented, separately tested revision follows. It does not raise aggregate limits, reduce the 6×6 envelope, split visible group publication or skip the native-client gate.

## Task 1.2: approved foundation and successful contention gate

`scripts/scheduler.lua` freezes each actual tick's render reservation. Presenter requests cannot retroactively change it or reset spent credits. Demand may boost the old 60000 reservation to at most 160000, leaving 40000 for preceding maintenance; every boost must be separated from the next by a baseline opportunity with 140000 non-render headroom. Even stale continuous demand cannot monopolize the scheduler. Both render and non-render service still debit the same 200000-unit maintenance ledger; guest/host ceilings are unchanged. Invalid retained demand is refused rather than repaired with fresh credit.

`scripts/services/monitor.lua` replaces the atomic whole-inventory partition setup with prepaid, durable indexing, insertion-sort and rectangle cursors. A shifted item remains separately rooted during sorting. Published groups remain intact until the existing complete reconciliation commit. The signature includes partition-policy identity and current dimensions; this is not the later six-tile migration or presentation-format implementation.

`tests/monitor_budget_engine.lua` runs through the production control/lifecycle/scheduler owner. Its stress network has 256 real registered, wired native vertices, including a running computer and 255 separated monitor tiles. Spatial order opposes inventory order to exercise deferred sorting. Four prebuilt captured-geometry frames alternate complete native publications under continuous 160000 demand, validating real witness lengths 253–256 each time. Preparation of these particular frames is trusted setup, not a claim of one-callback guest construction; the separate task-1.1 fixture tests sliced preparation.

The test saves mid-sort with a shifted item and all 200000 maintenance credits spent. The second process verifies retained aliases/cursors, reservation/boost history, computer state and old-tick refusal, including an attempted request change at zero credits. Same-tick scheduler replay does not publish or renew credits. Normal actual-tick execution subsequently finishes topology while callback timers, a second notification timer and real render retirement continue progressing.

### Exact foundation matrix evidence

- Instrumented matrix archive: `$TMPDIR/tc-budget-final-package/tweaked-computers_0.1.4.zip`.
- SHA-256: `3af8aedfaecb6eaed4350a547d33f729c53701f1de8d2df6c66e443c1a1cbb1f`.
- Reports: `$TMPDIR/tc-budget-final-{contract,native,live,runtime,monitor,feedback,workspace,editor,integration}/summary.json`.
- Real-scheduler logs: `$TMPDIR/tc-budget-final-live/{base,space-age}/cold-second-engine.log`.
- This archive predates the updated report bytes. A documentation-updated replay uses `$TMPDIR/tc-budget-verified-package.json` for its exact external hash and `$TMPDIR/tc-budget-verified-*/summary.json` for results, avoiding a self-referential hash in packaged documentation. Do not attribute one archive's hash to another.

| Observation | Base | Space Age |
| --- | --- | --- |
| Scheduled steps through topology completion | 190 | 190 |
| Boosted / baseline opportunities | 95 / 95 | 95 / 95 |
| Complete four-member native publications | 95 | 95 |
| Running neighbor beat callbacks | 94 | 94 |
| Additional timer notifications | 26 | 27 |
| Completed production logical groups | 255 | 255 |
| Highest observed maintenance ledger spend | 194076 | 194076 |
| Highest observed host ledger spend | 14159 | 14159 |
| Retirement object destroyed | yes | yes |
| Cold retained-state and old-tick zero-credit checks | pass | pass |

The fixture also synthetically exhausts exactly 200000 credits before its cold snapshot; the observed maximum above describes ordinary scheduler steps, not that explicit pressure setup. These are scheduler-step counts, not end-to-end graphical latency or factory power-grid acceptance. Native refill, initial frame/network construction, cold-save waiting and observer assertions are excluded from scheduler CPU samples. Production grouping remains four-tile; real six-tile grouping and selected-group authority integration belong to later tasks.

### Whole-budget and finite-cap derivation

The reference preflight/publication costs are unchanged: 20296 current-witness work plus 127088 native visibility/bookkeeping work = 147384. They fit a 160000 whole-commit admission; remaining future coordinator checks must also fit that hard cap before any visibility change. The absolute maintenance ceiling stays 200000, rather than being increased to the failed initializer-plus-publication total.

The planned presentation residency envelope is conservative and finite:

- At most 80000 front cell slots, 10584 admitted staging slots and 10584 queued retirement slots. Invalid fronts remain charged as owned fronts until retired; removal cannot make their objects unaccounted.
- Staging and retirement each also cap frame records at 256. This adds metadata backpressure when tiny grids would otherwise allow too many panel/cursor records.
- Monitor-owned native objects: `2*80000 + 4*10584 + 6*256 = 203872`. The final term covers front/staging/retired panel and cursor allowances. Unrelated device artwork is not reclassified as presentation-owned.
- Model/snapshot cell slots: `3*80000 + 2*10584 = 261168`, covering working, displayed, newest-pending, admitted and retired values.
- Native render-record cell slots: `80000 + 2*10584 = 101168`. Combined conservative retained-cell slots: `362336`.

These are derived cell/object ceilings, not a measured byte-memory claim or already exposed `getLimits()` fields. Later tasks must implement query/enforcement/backpressure and full-world residency acceptance; the foundation does not silently claim them complete.

### Complete scheduler versus native CPU observations

The following serial samples belong to the instrumented archive above. Native samples include witness validation and complete preflight/publication, but not construction, observer visibility assertions, factory-grid refill or client graphics. Full scheduler samples cover the real production phases including that hook; post-dispatch observer assertions are outside the profile. Profiler objects stay ephemeral and never control scheduling.

| Sample family after cold reload | Base | Space Age |
| --- | --- | --- |
| Native publication, 94 samples | 21.217037–87.749710 ms | 22.191564–73.088905 ms |
| Complete scheduler, 13 samples across baseline and boosted ticks | 15.339738–60.755123 ms | 15.616947–45.498294 ms |

This passes the revised abstract-budget/fairness gate, not a 60-UPS/FPS gate: multiple observed operations exceed a 16.7-ms frame interval. The samples are not a matched latency benchmark or p95 acceptance. Production preparation, application-frame completion, graphical tearing and peer synchronization remain unverified.

### Regression coverage and replay

The same instrumented archive passed nine suites in base and Space Age: budget contracts, native buffer probe cold, production-context budget contention cold, runtime contracts, monitor cold, production-context monitor-feedback cold, editor workspace with candidate data, editor cold, and production-context integration cold with candidate data. There are 18 mode cases and 24 cold server phases; each cold phase acknowledged console `/quit` without SIGINT or forced kill. Task 6.1 remains pending for the final implemented feature, not checked merely because its current-foundation regression matrix passes.

Rebuild after editing packaged documentation; use fresh replay outputs and compare the exact resulting hash rather than substituting the instrumented archive's hash. The production-context flag for `tests.monitor_budget_engine` requires `--cold`. Example replay:

```sh
python3 tools/build.py --output "$TMPDIR/tc-budget-verified-package" \
  > "$TMPDIR/tc-budget-verified-package.json"
archive="$(jq -er .path "$TMPDIR/tc-budget-verified-package.json")"
python3 tools/smoke.py --factorio /home/siredvin/tools/factorio/bin/x64/factorio \
  --archive "$archive" --output "$TMPDIR/tc-budget-verified-live" \
  --fixture tests.monitor_budget_engine --production-context --cold --mode both
```

## Historical foundation boundary and current deferred acceptance

At the foundation checkpoint, the next task was the original native-client
gate. The subsequent user authorization explicitly removed graphical/client
validation as a blocker for this alpha, without treating it as passed. The
production implementation and release procedure above supersede that earlier
rollout boundary; the foundation's old archive hashes remain historical.

The installed executable reports `headless`; DISPLAY and WAYLAND_DISPLAY are
unset. A headless binary cannot establish native world appearance, input or
peer-visible synchronization. Tasks 1.3 and 6.3 remain unchecked for the user's
review. Backup saves before testing; keep screenshots and client logs outside
the repository.
