# Resource-policy implementation evidence

This is an **unfinished implementation checkpoint**, not a release candidate or completed resource-policy contract. The approved scope remains all 47 tasks in `openspec/changes/replace-arbitrary-limits-with-resource-policy/`.

The [source-site disposition inventory](resource-policy-inventory.md) maps every policy-manifest audit row and shared limit constant to its implementation paths and required treatment. Inventory coverage is not proof that those limits have been removed.

## Scalar validation metering checkpoint

Validation-only string transfers now retain their constant type/length check
without charging an unperformed byte scan. The internal guard's default path
still prepays string comparison work: emitted comparisons, default sorting and
`rawequal` retain their existing charges. Native copying/transformation, key
processing, retained-byte admission and existing trust/domain checks are not
relaxed. Return, assignment, insertion and continuation-binding validation use
the validation-only path; no compiler format or production budget changes.

The heap fixture regresses short/long validation cost, comparison admission,
retained string bytes and the existing oversized-string refusal. The original
production archive fails the new constant-cost assertion; the candidate passes
the heap fixture in base and Space Age with clean separate-process cold reload.
Evidence is preserved under
`/home/siredvin/artifacts/tweaked-computers/resource-policy-scalar-validation/`.

This does **not** complete task 3.4: the unchanged mixed-chart oracle still
rejects an incomplete model during a suspended draw. Diagnostic-only runs expose
both work and allocation pressure; they are not acceptance or client performance
evidence. The mixed fixture, chart source, deadlines and budgets remain unchanged.
The overall checklist remains **12/47**; Configurator transaction admission,
durable compiler trust/accounting and full integration remain open.

## Native oversized speaker inventories and maintained examples

The new `speaker_resource_engine` fixture installs **real native prototypes**:
65 additional instruments, a 129-note instrument, 32,769 named sounds and valid
instrument/note/sound names longer than 256 bytes. It uses an actual wired
programmable speaker, production program scheduling and a live page-size setting
of 73; no runtime catalogue, authority or audio sink is replaced in this fixture.

Both base and Space Age pass complete sorted pagination of the 32,769 test
sounds, defensive note snapshots, native pitch validation and sequential
submissions beyond the former per-speaker ceilings. A separate-process cold
reload during pagination retains the run, count, spent work and start/submission
markers. Native speaker configuration remains unchanged. The same fixture then
executes all three maintained speaker examples; the melody now explicitly
requires a successful sequential return rather than branching on a retired
quota-rejection result.

The expanded `speaker_admission` fixture also exercises real wired discovery and
playback. Its separately labelled native-sink/authority doubles still verify
exact native-call counts and failure/revocation boundaries. A new cold case
exhausts the real work ledger before submission (rather than merely injecting a
suspension), verifies zero submissions at that boundary and exactly one after
reload. The existing before/after/failure/revocation cases remain intact.

The two fixtures pass in both modes: **four native cases and eight clean cold
phases**. Build, animation-wrapper/settings tests, generated examples/catalogue,
strict OpenSpec and MkDocs/player-doc checks pass. Final archive/source hashes,
native result markers and receipts are recorded in
`/home/siredvin/artifacts/tweaked-computers/resource-policy-speaker-native-inventories/verification-index.json`.
CI adds the oversized fixture without removing the legacy speaker fixture.

This is native catalogue/submission evidence, not audible playback or connected
multiplayer acceptance. The legacy `speaker_engine` still contains retired
quota assertions, a non-durable guest driver and a Configurator transaction
dependency; its migration remains open. Task 8.3 and overall integration are not
closed by this checkpoint; progress remains **12/47**. Production budgets and the
unchanged controller/chart gates were not modified.

## Protected-call refusal and application-state recovery

Task 4.2 is complete; overall implementation progress is **12/47**. The exact
archive, source correspondence, fixture receipts and failed/diagnostic attempts
are recorded in
`/home/siredvin/artifacts/tweaked-computers/resource-policy-protected-state/verification-index.json`.
This is a language/control milestone, not full resource-policy acceptance.

- Real retained-heap saturation exposed two defects: caught native refusals did
  not expose their original source location, and `xpcall` admitted its failure
  tuple after leaving control unwinding. Source fields are now admitted with the
  diagnostic snapshot, and the bounded failure tuple is prepaid in the existing
  control reserve before invoking the message handler. Neither guest credits nor
  production reserves were increased. Guest edits still cannot forge or change
  trusted diagnostic provenance.
- Caught application-state byte refusals now report `state_bytes` and
  `tc-state-bytes` before publication. Uncaught refusals terminate only the
  invocation, preserving accepted state and the active run. Reads, equal-size
  replacement, shrink and deletion remain available after lowering the storage
  ceiling; growth is refused without partial publication.
- Eleven fixtures pass in both content modes: `resource_policy_capacity`,
  `resource_policy_runtime`, `resource_policy_computer`,
  `resource_policy_language_control`, `computer_contract`, `runtime_contract`,
  `resource_policy_refusal`, `resource_policy_memory`,
  `resource_policy_heap_memory`, `resource_policy_functions` and
  `resource_policy_state`. These provide 22 native cases and 20 clean cold phases.
  The final five fixtures use separate-process cold reload; the state fixture
  also uses real production-context setting changes and scheduler dispatch.
- Coverage includes nested protection, nil/false results, failing message
  handlers, depth refusal, private suspension, explicit Stop, real heap refusal,
  original locations and cold provenance/re-entry preservation. Existing
  injected-error cases remain explicitly distinguished from real heap pressure.
  The state fixture lowers the live ceiling, reloads accepted over-limit state,
  reads/shrinks/deletes it, raises the ceiling and verifies recovery without
  startup replay or renewed same-tick work credits.

The prior runtime return-boundary fixture now prepares its empty result before
its test-side effect, matching the production service contract. CI runs the
protected-call/state matrix before the still-failing legacy speaker integration.
Package, animation-wrapper, settings, generated-contract, strict documentation
and OpenSpec checks pass separately from native execution.

Tasks 2.2–2.4 remain open: this does not establish universal ownership/control
admission or grandfathering of shell graphs, drafts, pending work and queues.
Legacy generic Data/string/key transfer ceilings still block larger-shape
probes; those failures are preserved rather than presented as state acceptance.
Compiler continuity, mixed-chart performance, full speaker integration,
native-client UI/audio and connected multiplayer remain incomplete.

## Speaker policy-v2 introspection (not full speaker acceptance)

Speaker `getLimits()` now uses the shared descriptor registry and returns
`policy_version=2`, applicable `resources`, and `tuning.speaker_sound_page_size`.
It no longer copies flat legacy limits or advertises unrelated device settings.
The player/API companion and generated example guidance describe the breaking
shape and remove the old count-quota/false-admission workflow.

Evidence: `/home/siredvin/artifacts/tweaked-computers/resource-policy-speaker-policy-v2/`.
Verified archive SHA-256:
`d46d78d082c7abb5e2ae0ccccefddc12d6500406dd7258de8bab29ddba151414`.

- A guest-level regression fails against the old provider and passes after the
  fix, checking metadata, defensive nested snapshots and argument validation.
- The expanded `speaker_admission` fixture also uses real wired computer/speaker
  entities and the production peripheral dispatcher to check powered/unpowered
  introspection, shared descriptor agreement and the non-introspection power
  guard. These checks do not replace the explicitly doubled audio-boundary tests.
- `speaker_admission`, `resource_policy_settings` and `runtime_budget_engine`
  pass in both content modes on the exact archive: six native cases and twelve
  clean cold phases. Settings tests verify speaker descriptors after native live
  changes and cold reload without renewing same-tick credits.
- Package, animation-wrapper, settings, planning-example, generated-catalogue,
  OpenSpec, strict MkDocs and player-documentation checks pass. An initial package
  check caught a link to an unbundled evidence page; its failure is retained, and
  the companion now explicitly names the repository-only report without a broken
  bundled link.

The full `speaker_engine` fixture still fails on this archive at its legacy
non-durable guest invocation (`tests/speaker_engine.lua:43`); its quota-based
assertions and production integration still need migration. No full task is
marked complete by this scoped correction: progress remains 11/47. Audible
playback, connected multiplayer, complete resource ownership and the other
feature acceptance gates are not established by these passes.

## Speaker outcome admission correction (not full speaker acceptance)

The real continuation/memory guard exposed a retained-growth defect in the speaker
submission record: `failed` was added only after the irreversible native call.
Both outcome fields are now initialized and admitted before playback. The native
regression fails before the fix and passes for successful and failed submissions
afterward, including exact job storage and prepared boolean-result checks.

Evidence: `/home/siredvin/artifacts/tweaked-computers/resource-policy-speaker-outcome-admission/`.
Cold candidate SHA-256:
`d5e9684e226afe7a684bb04fcd283011c800224b5985aa9f344eeac40c10b61d`.
`tests.speaker_admission` passes in base and Space Age with four clean cold process
phases. The fixture freezes before submission, after success and after failure
but before result delivery. It verifies unchanged saved progress on load,
exactly-once submission/result delivery, refusal after authority revocation and
complete owner release. CI now runs this fixture with `--cold`.

Compilation, continuation, memory admission and result delivery use production
code; audio and authority endpoints are explicitly doubled, and suspension is
injected at the exact boundary. This is not native audibility, complete production
network integration, work-exhaustion coverage or full task 8.3 acceptance. The
older `speaker_engine` contract migration, other owner coverage and the remaining
feature gates are still open; the overall progress remains 11/47.

## Direct integration checkpoint (2026-10-24; not acceptance)

The integrated change has **11 of 47 tasks complete**. Task 2.1 now has native
policy-v2 introspection, settings/default/unit and same-tick accounting coverage.
This does not complete owner enrollment, durable compilation or feature acceptance.

Evidence: `/home/siredvin/artifacts/tweaked-computers/resource-policy-direct-checkpoint-2026-10-24/`.
The bundle retains exact archives, source differences, failed attempts, diagnostic
archives and a machine-checked `verification-index.json`:

- `scalar-transfer` archive SHA-256:
  `f5065f67a972739a2141655a19aeb92701cb55009f7a20b7a06639aee76793a4`.
  Heap/function fixtures pass in base and Space Age with cold reload. Compilation
  cache, compiler cache contract, compiler cursor trust, runtime and computer
  contracts pass in both modes without cold reload. Bounded concatenation uses
  prepaid native results; primitive-only private tuples avoid defensive copies;
  the private trusted native factory cache preserves charged reconstruction and
  isolated executable tables. None enables the quarantined durable compiler.
- `settings-integration` archive SHA-256:
  `70d1b4ba34ad051dc8e70cb43320f2200cae17a66392f5e57ceb62505707fd4d`.
  Settings, runtime-budget and logic fixtures pass in both modes with cold reload.
  The production difference from the scalar-transfer candidate is `logic.lua`:
  malformed retained subscription details now produce controlled refusal, rather
  than a nil-index host crash, including when sampling lacks maintenance credit.
  Valid work deferral preserves the run and baseline and marks resynchronization.
- The fixture totals above are **20 native cases and 20 clean cold process
  phases**, excluding charts. Every cold phase exits zero with acknowledged
  console `/quit`, no SIGINT and no forced kill.
- The unchanged four-wall chart passes in both modes on the scalar-transfer
  archive, including cold phases and at least 360 publication intervals per mode
  with maximum two-tick gap. The unchanged **mixed-layout chart still fails**.
  No budgets, workloads or chart assertions were weakened; tasks 3.4 and 9.5
  remain open. These are headless publication results, not GPU/FPS evidence.

The initial logic invocation used unsupported `--production-context`; its harness
failure is retained separately from the successful `logic-engine-supported` cold
run. Earlier settings/budget failures and the instrumented chart diagnostic are
also preserved, not counted as acceptance.

Draft PR #35 is an integration checkpoint, not a merge-ready delivery. The existing
`a75d17b` CI failure in `speaker_engine` is retained in the bundle. Production
Configurator calls still lack `guard.commit_configuration`; durable compiler
execution remains fail-closed pending trust/allocation validation. Complete owner
accounting, remaining integration, upgrade, full-client UI/audio/render and
connected multiplayer acceptance are unfinished. Historical passes below do not
establish those gates for this candidate.

## Consolidated checkpoint: `f571405` (historical, not acceptance)

The current integration branch is `feature/resource-policy-completion`. Lane
commits and foundation/UI work were collected at `1a33bd4`; `258b4c7` fixes
observation timestamps and documentation, and `f571405` removes redundant
ownership/tuple preparation and bounded native-copy allocation. Earlier sections
below describe historical archives, not acceptance inherited by this checkout.

Evidence: `/home/siredvin/artifacts/tweaked-computers/resource-policy-consolidated-f571405-2026-10-23/`.
Candidate SHA-256: `b9bdfdac6fd96e4ae1473ee77c510ae565ace4d7e7b7f1a3662924a819501aac`.

- Heap ownership and function-continuation fixtures pass in both modes: four
  native cases, eight separate clean cold phases with acknowledged `/quit`.
  The heap fixture includes constant-shape replacement, atomic memory refusal,
  scalar-result storage reuse and the 256/257-byte native-copy boundary.
- Packaging, animation-wrapper, settings, generated examples/catalogue, strict
  MkDocs and player-doc checks pass. These establish task 11.2 only.
- The unchanged four-wall gate **fails** at tick 6 in the shared-model oracle
  (`tests/monitor_animation_engine.lua:62`). This is not evidence of visible
  front-buffer tearing. The earlier consolidated candidate also failed cadence
  with a three-tick gap. Budgets, workload and assertions were not weakened.
- Mixed-layout, full-client and connected-multiplayer acceptance were not run
  after this early-gate failure. Task 3.4 is reopened for the integrated tree.
- The durable compiler remains quarantined: task 4.4 needs a safe representation
  and real memory integration, not simply re-enabling its public methods.
  Monitor ownership, other owner/lifecycle paths and contract migration remain
  unfinished. The preserved monitor-memory helper is not integrated acceptance.

`verification-index.json` distinguishes passes, failures and unrun gates. The
diagnostic-only archive is separate and changes only the test fixture; it is not
a production acceptance archive. No feature-completion claim is made.

### Review correction: empty substring ranges (`b26b8c1`)

Review found that `f571405` passed a negative normalized substring endpoint to
native `string.sub` a second time. An empty range could therefore copy a large
input after admitting zero payload bytes. A native regression reproduced the
failure; `b26b8c1` returns the empty result before that native call. Tests include
a 10,000-byte input, negative/out-of-range and reversed endpoints, result reuse
under a lowered memory limit, and ownership release.

Evidence: `/home/siredvin/artifacts/tweaked-computers/resource-policy-empty-substring-b26b8c1-2026-10-23/`.
The corrected archive SHA-256 is `f4568785e1272eaf14b468966bae66454dbee7bb7ac802aa33129e8626d8770f`.
Heap and function fixtures pass four native cases/eight clean cold phases in
base and Space Age. These are bounded regression results, not chart or full
feature acceptance. The original `f571405` archive is superseded for this fix;
its preserved failures and earlier receipts remain unchanged.

The corrected substring blocker passed independent specification re-review;
the four-file optimization diff `258b4c7..b26b8c1` then received code-quality
approval with no required changes. Both reviews were bounded source/evidence
reviews, not new engine runs or approval of the incomplete feature. The chart
regression and quarantined compiler remain open.

## Settings registration checkpoint (historical partial task 2.1)

Evidence: `/home/siredvin/artifacts/tweaked-computers/resource-policy-settings-aa769238bb43/`.
The tested package SHA-256 is `aa769238bb431f339c43730962cdbc40d9a0e42b2004a92a59b82f49e93402e2`.
The settings registry contains every approved setting, with localized descriptions,
resource units/scopes, positive ranges and monitor axes capped at six. This is
registration and refresh acceptance, **not proof of every owner's enforcement or
the completed policy-v2 introspection contract**; task 2.1 remained open at this
checkpoint. The direct integration checkpoint above supersedes that task status.

- `tests.resource_policy_settings` passes in base and Space Age in production
  context. It exercises every registered maximum through native settings,
  changed effective values, selected minimum allowances, derived maintenance,
  unchanged spent credits and retained ledger identity through cold reload.
- `tests.runtime_budget_engine` passes its unchanged execution/accounting
  regression coverage in both modes with the revised maintenance setting range.
- Each fixture has two separate cold phases per mode: all recorded exits are
  zero, console `/quit` is acknowledged, and no signal or forced cleanup is used.
- `python tools/test_resource_policy_settings.py` passes manifest/localization
  agreement; all 18 packaging tests pass and reproduce the tested package hash.
  Static checks are not native enforcement evidence.

The original failing settings fixture and its build receipt/log remain under
`settings-red/` in the bundle. The earlier interrupted lock wait is not counted
as an engine failure or a passing run. Subsequent implementation changes need
their own integrated archive and acceptance; these results cannot be inherited
by a changed runtime or service implementation.

### Accounting-domain review correction

Review found that the new legal work settings could exceed the scheduler's old
one-billion retained-total validator. The added native regression reproduced
that failure before the fix (`settings-accounting-red.log`). Guest reservations,
maintenance costs and retained totals now share the safe-integer domain;
admission checks remaining allowance before adding a charge.

The corrected package SHA-256 is
`d7ff8c8c4be9835ee8e1925c43e100b1049c4bf2e17a286d535d91f61424c496`.
Both `settings-accounting/summary.json` and
`settings-accounting-budget/summary.json` pass base and Space Age, including
two cold phases per mode, acknowledged `/quit`, zero exits and no forced
cleanup. The new fixture covers accumulated and individual spending above
one billion, scheduler entry, next-tick rollover, invalid amounts and exact
refusal near the safe-integer maximum. Spec and follow-up code-quality reviews
approved this bounded registration/accounting change, not full task 2.1.

These newer receipts and the failing attempt currently remain in
`/home/siredvin/.hermes/profiles/albina/cache/scratch/tc-policy-parallel-QqFKCi/`.
Copying this newer bundle to durable artifacts was not authorized by the tool
approval prompt; it has **not** been preserved there. The earlier durable
settings bundle above is not evidence for this correction.

## Scope and source

- Implementation base and fetched `origin/main`: `d9e17929620ee9995a6b3235635ac12a283a0e72` (includes the approved planning change).
- Isolated feature branch: `tweaked-computers/t_b473a1fb-implement-approved-configurable-resource`.
- The cancelled signal-read investigation is diagnostic context only; none of its acceptance is inherited. No Ctrl+click work is duplicated. Publication/integration remains downstream card `t_4efacf8e`.
- Durable evidence root: `/home/siredvin/artifacts/tweaked-computers/t_b473a1fb-resource-policy/`. Archives, maps, logs and screenshots do not belong in git.

## Acceptance matrix

| Area | Intended change | Unchanged acceptance |
|---|---|---|
| Program/Console execution | Private durable continuation; work suspension, recoverable capacity refusal | Supported grammar, lexical/evaluation/tuple semantics, authority, deterministic shared credits, source diagnostics |
| Effects and persistence | Retain next uncompleted primitive and pending return delivery | No startup/effect replay, no execution or ledger renewal in `on_load`, cold and late-join equivalence |
| Events | Drop newest with durable visible diagnostics | Accepted FIFO order, timer deadlines, output fail-safes, no silent command/write loss |
| Native inventories | Remove shape/cardinality gates end to end | Complete defensive snapshots, native domains, coherent observations and current authority |
| Monitor | Invocation-aware sealing, resource-owned buffering and named groups | 6×6 axes, atomic publication, at least 360 intervals per mode/layout with maximum two-tick gap; native-render gates |
| Storage/settings | Configurable growth admission, grandfather accepted data | Atomic refusal, reads/deletion/transport after decreases, explicit migrations |
| UI/audio/multiplayer | Visible pressure and complete scrolling/refresh | Real client interaction/audio/render evidence and connected late join, not mocks/headless substitutes |

## Baseline: task 1.3

`baseline/source.tar`, `source-commit.txt`, `source.sha256` and `build.json` freeze the unchanged source and archive. Baseline archive SHA-256: `bb0548550cfee1ecf1accdcaf2aef3ad143dcebd5d878af0914df648ce61b982`.

All runs use Factorio 2.0.77/build 84539, isolated config/mod/write/save directories, and the packaged archive. Both base and Space Age pass:

- `baseline/runtime`: 64 counted contract groups per mode.
- `baseline/computer`: 92 groups per mode, followed by two separate cold server phases.
- `baseline/console`: the production-context shell cold fixture, with two cold phases per mode.
- `baseline/animation-four-walls` and `baseline/animation-mixed`: 360 complete publication intervals per mode/layout, maximum gap two ticks. Each wrapper records its test-only archive and guest hashes separately from the unchanged input archive.
- `baseline/maintenance-unprofiled-v2`: 600 real scheduler samples per mode, 40 input observations each, zero measured input-to-effect tick latency, no faults. Scheduler means 1.370486 ms (base) and 1.451662 ms (Space Age); these are host-specific samples, not a hardware-independent latency promise.
- `baseline/maintenance-profiled-v2`: separate 600-sample phase-instrumented runs, with exact registration-derived profiler inventories. Observer-inclusive timing is not substituted for unprofiled controls.

Successful cold phases have completion markers, acknowledged console `/quit`, zero engine exits and no signal/forced cleanup. Full logs and host-contention samples remain in the bundle.

The first profiled benchmark reported structural failure because its extractor expected 15 phases while production registered 17. That failed attempt remains under `baseline/maintenance-profiled`; it is **not** an accepted timing baseline. Commit `94e1ca9` replaces that stale count with an independently logged registered-phase inventory and exact set/per-phase sample checks. Seven host regressions cover added/missing/duplicate phases and samples. Both profiled and unprofiled controls were rerun as `*-v2`; neither the production budgets nor workload/cadence gates changed.

## Desired red contracts: task 1.2

The added opt-in entry points extend, rather than disable, the existing runtime/computer/cold assertions:

- `red/runtime`: fails against the old runtime with `slice must suspend, not fail: callback budget exhausted`.
- `red/computer`: fails because work pressure retires the active run.
- `red/cold`: fails in the first real server process because no unfinished healthy invocation can be saved.
- `red-capacity`: a separately recorded diagnostic ZIP changes only the two inventoried fixture members of the unchanged baseline. It fails because uncaught capacity exhaustion retires the run. Its provenance explicitly distinguishes the diagnostic bytes from the embedded baseline package manifest.

These are expected red assertions, not candidate acceptance. Complete logs, commands and exit codes are retained, including the nonzero first cold server exit.

## Durable scalar vertical slice (partial tasks 3.1–3.2)

`slice-03/results.json` records four passing packaged fixtures in both engine modes. `slice-03/build.json` identifies the exact tested archive; later edits require a new package and rerun.

- `tests.resource_policy_runtime`: both descriptor/declaration finite scalar loops span paid slices, preserve locals and the completed prefix, and do not renew credits on same-tick retry. A trusted forwarding boundary deliberately exhausts work **after** a service effect; its saved result prevents duplicate delivery on resumption.
- `tests.resource_policy_computer`: the production scheduler preserves an unending invocation, serves a finite neighbor and accepts host Stop without losing accepted state.
- `tests.resource_policy_cold`: a declaration loop resumes after a separate-process cold save with an unchanged graph/ledger and no prefix replay.
- `tests.resource_policy_engine`: real powered/wired computers and KV peripherals use the actual `peripheral.wrap`, captured `db.set`, native service checks and production scheduler. Both source forms save inside finite loops after one database mutation. Cold reload preserves symbolic facade/method aliases, original run, locals, queued FIFO and spent credits; only remaining effects execute, and a finite timer-driven neighbor progresses. The graph is checked for functions, threads, LuaObjects and metatables.

The checkpoint ABI is private and experimental. The scalar lowerer deliberately reports unsupported syntax rather than silently executing an unsupported continuation with a native fallback. The older direct compiler test entry remains during this staged transition; production program dispatch now passes an explicit invocation checkpoint. **Do not publish this intermediate branch:** language coverage, Console integration, aggregate resource accounting, incremental compiler/service preparation, migrations, monitor completion holds and the matched continuation performance gate are not yet complete. No complete task 3.1/3.2 acceptance is claimed from these subset proofs.

## Latest scalar checkpoint: `61b69d63f7da7064774686bb5a59fb228f09201f`

`slice-07` is the latest tested code checkpoint. Its source archive and complete source patch have separate SHA-256 records alongside the tested package hash. All five recorded fixtures pass in base and Space Age: the real production-context cold engine fixture, scalar runtime, runaway/Stop scheduler, synthetic-clock shell staging/arity, and the original 64-group direct runtime regression.

The real cold engine fixture now saves **both a suspended program and a staged Console command** on the same computer. Console ingress uses the real editor handlers with explicitly mocked player/GUI tables; this is not native UI evidence. Both lanes have already written KV data. They resume without duplicate database writes or print output; scratch `x=10` remains unpublished until successful command completion commits `x=300000`. Saved-only source edits do not replace active source, FIFO callbacks follow the unfinished program, and the scheduler's next-lane selector and spent credits survive cold reload. The first attempt at Console ingress correctly refused on a tick whose callback credits were already exhausted; the fixture now submits on the next real tick rather than renewing credits. Full failed logs remain in `slice-05`.

`idle-baseline` and `idle-slice` are serial matched controls: three 600-sample runs per engine/implementation, 1,800 samples per combination, identical guest source/settings/observer. Both preserve ten controller beats in each run with no fault or cleanup failure. `idle-comparison.json` records the complete aggregate. Baseline/slice whole-scheduler means are 0.113240/0.133503 ms (base) and 0.113340/0.135281 ms (Space Age); accounted mean guest work rises from 77.7833 to 156.2667 units. These small-workload results **do not satisfy task 3.4**: retained-growth measurement, input contention and the original monitor workloads are not yet verified. Host-contention data and tails are preserved; no FPS/UPS claim is made.

`slice-07/full-computer-regression` was also actually run and **fails** at `computer_contract.lua:83` with `continuation slice requires one local assignment`. The original assertions were not removed. This is an incomplete language-lowering requirement, not a passing full computer matrix or evidence that the complete architecture meets the original chart gate.

At `61b69d6`, widening heap-allocating language coverage still required ownership/lifetime accounting and reclamation: the saved `owned` and symbolic-binding registries held strong references and were not an aggregate retained-memory bound. The resumed checkpoint below fixes index reclamation, but not complete capacity admission. General compiler/service preparation is still not incrementally resumable; checkpoint validation was also monolithic at that checkpoint, and is addressed by the later bounded-validation milestone below. These gaps keep the branch explicitly unpublishable, even though the bounded scalar/cold proofs pass. The private ABI is experimental; production migrations and compatibility acceptance remain open.

## Resumed ownership and scalar-assignment checkpoint

Evidence: `resume-ownership-01/`, with the source freeze and tested archive listed in `SHA256SUMS`. The latest tested package is `liveness-package-02/tweaked-computers_0.1.13.zip`, SHA-256 `4f8c846752c5dbf229986b8ce5f1b061f5ebbd24ab87441f0913b4d2b23cc6c0`. This remains an **unfinished, unpublishable checkpoint**, with only tasks 1.2 and 1.3 complete.

- Scalar lowering now supports uninitialized/multiple locals, multiple assignment, nil-containing/empty result adjustment, final-call argument expansion and multiple Console expression results. All RHS expressions execute left-to-right, including discarded results; duplicate assignment targets publish right-to-left only after full preflight. No heap constructors, nested functions or protected-call continuation coverage is claimed.
- Compiler control-flow liveness emits prepaid cleanup for each successor edge. Dead local/scalar/tuple slots are cleared with the successful block, not left as accidental ownership roots. Branches, numeric loops in both directions, repeat/while, breaks and aliases surviving long waits are exercised in both source forms.
- `scripts/runtime/ownership.lua` incrementally traces explicit root ranges and saved guest-key vectors, follows a captured method's facade, and sweeps unreachable guest/symbol/binding indices. Each paid action advances a saved cursor; it never persists a native hash iterator or relies on weak-table/Lua-GC timing. Sandbox construction, copies, raw assignment, table mutation and shell decoding maintain those key vectors before publication.
- The private checkpoint ABI is now 2. ABI 1 experimental checkpoints are refused and retained, not replayed or silently repaired. This is not the still-required migration from shipped legacy runs. The collector's `memory_bytes` is a provisional deterministic live-root estimate (frame/entry/ownership metadata plus unique strings and aliased graph objects), **not yet an enforced or complete runtime/host-memory allowance**. Aggregate program/Console admission, temporary/collector peaks and service reservations remain prerequisites before widening heap syntax.
- `checkpoint-results.json` verifies all eight latest fixtures pass in both base and Space Age: assignment/liveness, ownership, actual guest allocation churn, scalar runtime, scalar Console, original 64-group direct runtime, real production-context program+Console cold continuity, and a separate mid-collector cold fixture. Both cold fixtures finish via acknowledged `/quit` with zero exits and no forced cleanup. The collector's one-action slices consume exactly the uninterrupted action count after a separate-process reload, with no on-load mutation. The 10,000-iteration guest test actually allocates cyclic tables through existing `table.pack`/`rawset`; after collection only the event remains, and releasing the final root empties the ownership indices.
- Historical failures remain separate: the first assignment fixture reproduces the one-assignment refusal; an uninitialized-local implementation attempt fails before correction; a collector invocation with unsupported `--production-context` is rejected by the harness and is rerun correctly as an independent cold fixture. The unmodified full computer regression still fails at line 83 (`func_proto` lowering missing), and full shell regression fails at line 66 (`localfunc` lowering missing). These are remaining engineering work, not an external approval blocker or passing gates.

The original controller/monitor performance gate and complete retained-capacity admission are still outstanding. These subset proofs do not authorize task 3.4, a release, broader language rollout or any production-budget increase.

## Resumed compiler-cache checkpoint

Evidence: `resume-cache-01/`. The final contract/cold package SHA-256 is `9b1205328abe0f83adc682afb5234957a4d1f238f796a03ba1311e8c5a697154`; the earlier timing package is separately frozen as `package-docs/` with SHA-256 `699caa8ec72a4a457323664c608a58883777745b6850041e44490dfa3f514768`. Production runtime/settings files are identical between these packages; the later package extends the cold fixture only.

- The compiler retains exact-source continuation text and its original charge proof privately, reusing the existing proof-replay path. Warm execution skips repeated parser/lowering CPU work, **not its charges**. No caller/saved generated text becomes executable authority.
- `tc-compiler-cache-bytes` is now a positive runtime-global setting (default 8,388,608 accounting bytes). It replaces the eight-plan cache and 32,768-charge trace cap with aggregate retained bytes including plan/key/source/generated text, names, trace entries and metadata. Batch eviction is disposable; an unfit proof is rebuilt, not refused. Locale, effective common limits and generated player docs cover this setting. This completes only the cache portion of the policy registry, not task 2.1.
- Seven final fixtures pass in both engines (`checkpoint-results.json`). The dedicated cache fixture compares cold, warm and evicted success/progress/complete credits, then verifies equal accepted prefixes and zero effects at one compile unit short. The real program+Console cold fixture now lowers the actual native setting to one byte after both lanes suspend, preserves it through cold load without renewing any ledger, completes with once-only effects and restores the setting through the registered production handler. Other passing fixtures retain ownership/churn, scalar runtime/Console and the original 64-group direct runtime contract.
- `idle-cache/` contains six serial unprofiled runs: three 600-sample runs per mode, each completing ten beats, zero faults and normal cold shutdown. `idle-comparison.json` uses the preserved baseline's actual per-tick samples. Baseline/candidate whole-scheduler means are 0.113240/0.109154 ms (base) and 0.113340/0.113786 ms (Space Age); candidate maxima are 1.596483/1.534767 ms. Charged mean guest work rises from 77.7833 to 200.1833 units after tuple/liveness changes. This idle workload contains no input observations and proves no input latency or original monitor cadence. No speedup/FPS/UPS claim is made; host contention and tails remain preserved.
- Benchmark config, workload, observer and monitor-wrapper overrides have identical hashes to the accepted baseline. The control override differs only because this branch's production test allowlist includes `tests.resource_policy_engine`; the fixed maintenance fixture still selects the same benchmark entry. The cached proof remains source-derived and can disappear on any peer without changing synchronized results.

Host build/animation-wrapper tests, player-doc generation/check, planning examples, strict OpenSpec and diff checks pass. Full retained-capacity admission, incremental compiler/checkpoint/service progress, full language and all remaining acceptance gates remain open. Overall checklist progress stays **2/47**.

## Resumed bounded-checkpoint-validation checkpoint

Evidence: `resume-validation-01/`; final tested package SHA-256 `34df03aea900234e63381d49b925ad0ea61493d5b25e7bede6af6e209dc51037`. `checkpoint-results.json` verifies eleven fixtures in both modes, including four cold fixtures (program/Console, ownership, explicit native key cursors and incremental validation). All final cold phases have completion markers, acknowledged `/quit`, zero exits and no forced cleanup.

- `scripts/runtime/checkpoint-validation.lua` replaces the whole-graph restart on every budget refusal with a versioned plain-data queue, visited identities and explicit table/key progress. It checks value kinds, metatables, local/temp/tuple index domains and tuple headers before execution; private cursor/header corruption is rejected rather than reset. The continuation's native callable bridge now additionally requires current guard registration.
- A trusted fixture injects a 2,500-entry cyclic private graph and lowers **test-only** execution credits to 4,096. It saves partway through that table, verifies unchanged frame position/cursor/ledger in `on_load`, preserves same-tick refusal, finishes validation without restarting its paid prefix and then reclaims the unreachable object before guest progress. This is private-graph validation evidence, not acceptance of large circuit reads or widened guest heap syntax.
- Pinned 2.0.77 documentation in `primary-documentation/` describes deterministic `next` ordering, rather than ordinary Lua hash-layout assumptions. An independent actual cold probe checks eight cursors over 2,500 numeric indices plus string, boolean, negative and reference keys, including self-reference and aliases. It saves **data keys**, never native iterator functions. This does not satisfy connected late joining.
- Plain strings need a type check, not a character scan. The final validator removes the old fictitious per-byte validation charge instead of retaining an unnecessary partial-string work subsystem. Ownership bytes, parsing, actual string operations and copy/transform admission remain separate obligations. The successful earlier partial-string prototype remains archived, but is not the final implementation or an extra accepted gate.
- Failed attempts are preserved. An initial low-credit fixture correctly encountered already-spent same-tick credits and was changed to wait for a real later tick, not renew them. Another attempt emitted completion in the initial server because its resume flag was armed on the initial load; the existing cold harness rejected it despite exit zero. The final validator/ownership/native-cursor fixtures arm resumption only when `on_load` observes the frozen phase, and their complete two-process gates were rerun.

Original direct runtime, scalar program/Console, assignment/liveness, ownership/churn, proof-cache and real factory cold checks all pass on the final package. Host build/animation-wrapper, player-doc, planning-example, configuration-catalogue, strict OpenSpec and diff checks pass. No current performance or whole-language acceptance is inferred. The full computer and Console regressions still require nested-function/heap lowering; the original controller/monitor gate, complete retained admission and service preparation remain open. Overall progress is still **2/47**, with no publication.

### Next prerequisite, not an approval blocker

Complete aggregate retained admission across the two lanes and their temporary/result owners before widening heap syntax. In particular, reserve recoverable-capacity and result metadata **before** a trusted mutation; `G.service` currently checkpoints scalar results but cannot safely encode an arbitrary raw host-table result. Reuse the existing preflight/prepared-return hooks and symbolic binding codecs rather than permitting post-effect memory refusal, native-object persistence or replay. Make refusal metadata survive diagnostics and end only the current invocation, with old accepted state/output intact. Compiler/parser/emission and service jobs still need their own durable preparation cursors; cache proofs are not incremental compilation. These are approved engineering requirements, not a need for user reapproval.

## Resumed trusted-result preparation checkpoint

Evidence: `resume-results-01/`; final tested package hash and exact mode/fixture list are in `checkpoint-results.json`. This prerequisite moves KV mutator result snapshots, immediate return admission and private encoded tuples **before** database publication, reusing the existing guard's prepared-return mechanism. The trusted service bridge verifies the promised result's exact arity/identities. A provider-contract violation is an engine error, not retryable work pressure. The collector follows both prepared tuple roots, and shared call/service result tuples are not double-counted.

`tests.resource_policy_results` checks every shorter work allowance, a deliberately injected storage-admission refusal, false/nil-containing results, both source forms and once-only progress after exhausting the remaining real ledger credits. Its native, electrically provisioned, wired KV scene injects refusal at the real result boundary for set/hset/hdel/del/expire/persist: each keeps the exact prior database object, then publishes normally on retry. This is boundary/fault-injection evidence, **not** an implemented configured runtime-memory policy. No new guest API, syntax coverage or service-result domain is claimed.

The final package passes nine fixtures in both engine modes, including production-context program/Console cold and the separate resource-provenance cold case. Earlier baseline and candidate full KV runs both actually fail at `tests/kv_engine.lua:217`, `continuation slice does not yet lower concat`; their complete logs remain separate. The first longer serial verification command hit its 180-second tool deadline after the seven regular fixtures and the base cold phase; no owned Factorio process remained. That interrupted cold directory is not final evidence. Fresh, individually bounded cold retries and the final nine-fixture run passed with normal exits. Host checks and strict OpenSpec pass. No performance, migration, connected-client, full-memory recovery or other outstanding acceptance is inferred; progress remains **2/47**.

The same checkpoint adds host-origin resource-error provenance with exactly the approved `E_CAPACITY`/`E_LIMIT`/`E_BUDGET` fields. Uncaught trusted refusals end the program invocation without retiring its run, timers, subscriptions or next accepted event; Console refusals keep its previous committed graph and principal-owned effects. Plain error fields cannot spoof this control path, and a forged `E_BUDGET` cannot masquerade as private suspension. `errors.refuse` is host-only. The cold fixture catches an injected refusal, edits its public message, suspends a long loop and rethrows after a separate-process reload; private plain ownership metadata preserves the original trusted diagnostic and original source position. The collector follows that metadata and its retained strings. This proves classification/continuity and Console cleanup isolation only: **the actual configurable byte/depth policy and emergency full-memory admission are still absent**, so tasks 2.2/2.3 and 4.2 remain unchecked.

## Resumed scalar-result admission checkpoint

Evidence: `resume-scalar-results-01/`. This is a further prerequisite for aggregate retained/temporary admission, not completed policy enforcement or permission to widen guest syntax. `prepare_boolean_result` (speaker) and `prepare_empty_result` (modem) previously prepaid only immediate native returns; their durable tuple encoding still ran after the external effect. The new regression first fails in the pinned engine with `scalar result refusal happened after publication`. Both helpers now use the existing prepared-result codec before publication. Boolean true/false share prepaid slots. Restoring a saved service result reuses its proof through caller delivery rather than taking an unprepared snapshot/encoding path. Invalid provider return shape is `E_ENGINE`, never private work suspension. The service frame is popped immediately after its protected native call, before validating results, so a caught provider-contract error cannot leave a stale private preparation frame.

The focused fixture checks every shorter work allowance and injected codec-storage refusal before the effect, exact zero/false/true arity, and no extra effects after resumption in both supported source forms. Its additional real two-process cold phase freezes specifically **between the service effect and caller delivery**, with `service_result` saved and `call_result` absent. All six cases preserve their frame position, shared tuple identities and spent ledgers without `on_load` execution, then deliver the result once. Cold tests require ordinary acknowledged `/quit` exits. These host-injected services prove result/checkpoint boundaries; they do not prove native audio playback, broadcast continuations or an actual configured full-memory refusal.

`checkpoint-results.json` lists the exact final package, focused matrix and normal cold exits. All failed/intermediate attempts are separate. A test initially filled the ledger without actually poisoning the guard, so it reached the next block and had no pending call; that correctly failed the stronger between-service-and-caller assertion. The corrected fixture explicitly triggers and catches the private guard only in its trusted test provider, then returns its real scalar result. The production sandbox still prevents guests catching suspension.

The original native speaker factory/upgrade fixture was also attempted. It fails at `speaker_engine.lua:252` on missing `constructor` lowering in **both** engines, in both pinned previous package `b554317a59b9810bde7344cdb21a6c2c5ee6f5b4ea39c43c74732eb1876f8ead` and this candidate. Neither upgrade/cold phase nor audible acceptance is claimed. An initial baseline path lookup failed before engine entry and remains retained separately; the corrected baseline was discovered from its actual build receipt and hash-checked before running. Full logs remain preserved. Original helper-admission/direct-runtime regressions pass, but they are not a substitute for the failing production factory or the original monitor/performance gates.

Actual runtime/host memory ceilings, emergency full-memory recovery and the earlier remaining requirements are still absent. Checklist progress remains **2/47**. No PR, push, merge, release, same-card review or accepted completion is implied by this checkpoint.

## Resumed computer/direct-effect result checkpoint

Evidence: `resume-computer-results-01/`. The same pre-effect guarantee now covers `computer.setState`, `deleteState`, `setLabel` and `log`. State counters, contents and labels are unchanged if result preparation refuses; log preparation happens before any oldest-entry eviction, including when history is full. `deleteState` retains exact true/false arity. Host diagnostics still use `runtime.log` without a guest return reservation; its new optional preparation hook applies only at guarded guest publication. The speaker client fixture's internal state writer now enters through the actual service guard rather than bypassing its return protocol; this does not constitute new rendered/audio/client acceptance.

The existing direct-helper return preparer now also prepays checkpoint storage for `rawset` and `print`. Service preparers reuse that path when their own guarded call is active, avoiding duplicate proof allocation. The focused fixture exhausts every shorter work allowance and injects codec refusal before either raw mutation or Console print; the effect stays absent on refusal and exact result identities/arity survive success. Native computer cases inject refusal at all four mutators and test both present/absent deletion plus full-history log retention. These are actual pre-publication checks, not a pretend implementation of configured memory bytes.

The exact final archive, real cold phases and regression results are recorded in this checkpoint's receipt. Aggregate runtime/host admission, other services' effect reservations and all earlier outstanding gates remain required. No additional OpenSpec checklist item is claimed complete from these prerequisites.

## Private memory-lifetime ledger checkpoint

Evidence: `resume-memory-ledger-01/`. `scripts/runtime/memory.lua` implements the first real retained-accounting primitive, separate from tick allocation credits. A shared account tracks accepted usage and outstanding peak reservations across multiple owners. Payload identity is charged once across owners; each owner/object link is separately accounted. Reservations transfer into admitted object growth without double-charging. Insufficient admission returns the existing host-origin typed resource refusal before changing the ledger. Lowering the allowance preserves accepted values and reservations; release and non-growing resize remain available. Constant-time linked owner records avoid an ever-growing tombstone vector. Closing an owner is a paid, saved-cursor job rather than an unmetered traversal or premature credit refund.

The current deterministic bookkeeping weights are 256 account bytes and 128 each for an owner, global value record and owner/value link; trusted callers supply payload accounting. Explicit control reservation counts against capacity. These are provisional accounting units, not Lua heap measurements. **The module is not yet connected to universal sandbox allocation or a live mod setting.** Its setting name appears in private test refusals only. It does not yet derive/prepay collector/validator workspace, implement diagnostic reserve borrowing/promotion, discover every payload size or protect host service allocations. Enabling it globally before those integrations and remaining pre-effect reservations would be unsafe; no feature flag or guest API was added.

`tests.resource_policy_memory` exercises shared object/string aliases, cycles, shared reservation pressure, peak-to-object transfer, refusal without ledger mutation, non-growing recovery below a lowered allowance, cross-tick retained growth and middle/head/tail release. The existing ownership collector now has a paid memory sweep for an explicitly supplied owner, preserving live guest/string/tuple charges and releasing unreachable ones. Checkpoints retain only the owner's numeric identity; the shared mutable account stays in host context, outside incremental checkpoint validation, so another lane cannot invalidate a saved validator cursor into its accounting graph. Missing/wrong/closing owners refuse continuation binding instead of silently rebinding it.

Its separate-process cold case saves both a partial owner-close job and the actual ownership collector's new memory sweep after one unreachable object has been released. Load preserves both linked cursors, accounts, reservations and spent work; same-tick retry advances neither job, and later paid cleanup uses exactly each uninterrupted action count without releasing a different owner's payload. A separate source-driven continuation verifies owner identity matching and absence of account backreferences. This proves the ledger/reclamation/binding primitives, **not** production allocation coverage, two live lanes exhausting a configured quota or scheduler maintenance fairness. Tasks 2.2–2.4 remain unchecked.

Next integration must attach allocation-time charges/reservations to existing ownership indices and prepared returns, include frame/tuple/string/binding and collector/validator peaks, then connect the shared computer account to both lanes and their staged/committed lifetimes. Existing `checkpoint.memory_bytes` is still only the older provisional measurement and must not be mistaken for the new account's complete usage. The first enabled scalar path needs the same cold/effect/cleanup tests before broader service rollout. Earlier original performance, full-language and native-client gates remain mandatory.

## Durable-container trust-boundary checkpoint

Evidence: `resume-heap-boundary-01/`. An actual pinned-engine red fixture found `table.pack(type)` retaining a native function in a suspended checkpoint. Protected namespace proxies could likewise be placed in guest containers without a durable encoding. The current early backend now refuses these unencoded values before publishing a new owned table, `rawset` entry/key or `table.insert` value. Nil-valued deletion does not retain its key and remains permitted. Existing encoded symbolic locals and bindings are not rejected by this check.

This is an explicit **temporary backend coverage limitation**, not satisfaction or reduction of task 4.1's callable/closure heap contract. Complete symbolic container encoding remains required before broad language acceptance. The historical direct runtime still accepts its prior cases; production does not silently fall back to it. The new fixture verifies both source forms, native direct compatibility, rejection with a plain checkpoint, safe symbolic function/namespace locals across suspension, and a real separate-process cold resume with once-only prepared completion and unchanged load state. No production memory setting or full-resource gate is inferred.

## Candidate executability checkpoint

Evidence: `resume-activation-01/`. A pinned-engine red fixture showed that a front-end-valid program unsupported by the early continuation lowerer could retire the accepted active generation before failing on first dispatch. Compiler preparation is now shared by draft validation, saved-source activation and durable dispatch: it verifies lowering and native syntax without executing a handler. The ephemeral prepared factory goes directly to the evaluator, never into storage or caller-controlled plan fields, so this introduces neither a second native compilation per dispatch nor a native execution fallback. Cache proofs and their charges remain exact-source-derived.

The focused native fixture verifies that rejected constructor/local-function/function-expression candidates preserve the active source, generation, FIFO event object/bytes, timers, subscriptions, state and spent credits. The editor-model path (mock player, **not actual GUI acceptance**) rejects the same drafts while retaining their text; successful validation keeps diagnostics plain and does not execute its candidate. These are pre-publication safety checks for the incomplete backend, not acceptance of the still-required syntax or incremental compiler jobs. Task 4.4 remains unchecked.

## Prepaid preparation-to-caller ownership checkpoint

Evidence: `resume-memory-handoff-01/`. Preparation jobs can now admit an owner and its peak reservation atomically, without leaving an orphan owner or consuming an identity when the combined request cannot fit. An explicit same-account sponsor can fund destination ownership links from its existing reservation. Ordinary lane allocations cannot consume that other owner's credit; shared payloads remain singly charged, and prepaid handoff remains non-growing in total usage even after a limit decrease. Invalid, closing or closed sponsors cannot fund delivery. A one-unit deficit refuses before changing either reservation or published ownership.

The native fixture freezes a paid adoption cursor after its first transferred object and resumes the remaining prefix in a separate process, checking unchanged load/same-tick credits and exact action count. Closing the preparation owner leaves delivered destination values alive; final teardown releases all records and credit. This is the private allocator mechanism required for snapshot/result staging, **not yet a production snapshot job, complete temporary accounting or universal memory-setting enforcement**. Existing result admission and baseline native evidence are not reclassified as full memory acceptance.

## Interactive scalar-slice acceptance: tasks 3.1–3.3

The interactive takeover closes these three **scalar-slice** checklist items, not full-language or resource-policy acceptance. Evidence is preserved under `interactive-takeover-01/` in the durable evidence root. Earlier checkpoints and their incomplete-status statements remain historical records.

- The production-context `tests.resource_policy_engine` fixture runs declaration and descriptor loops for 300,000 and 600,000 iterations, writes KV progress every 50,000 iterations, and cold-saves after each has crossed its midpoint but before completion. Separate-process reload preserves locals, exact binding/facade identities, active versus saved source, generation, queued FIFO, and paid ledgers. Final KV counters prove that neither the prefix nor loop effects repeat.
- Both source forms also run infinite handlers across the cold boundary. The finite neighbor continues. A finite Console command on the **same computer as an infinite handler** commits successfully; host Console reset leaves the program continuation intact, and explicit Stop cancels both runaways without renewing their work/allocation credits or repeating their log prefixes.
- A separate long Console command retains its staged `x=10` through the cold boundary and commits `x=600000` only on success. Its KV mutation and printed output occur once. These tests use real engines, electricity, wiring, services and scheduling, but mocked editor/player ingress; they do not claim native GUI or multiplayer acceptance.

### Storage and cancellation boundary

Each program invocation is retained in `rec.invocation`, with its dispatched event and private checkpoint tied to the active source/run. The independent Console lane is `rec.shell.invocation`; its staged graph is published as committed `rec.shell.values` only after successful completion. Budget suspension retains either lane; neither starts another callback/command while unfinished. The scheduler alternates competing lanes under one computer ledger. Cold load does not execute them or renew that ledger; synchronized dispatch reconstructs executable code from source. Program Stop retires its invocation and applies existing principal cleanup; Console reset cancels the shell lane without retiring the program. Completed external effects are not rolled back. Broader migration, full-resource recovery and native UI acceptance remain separate unchecked gates.

### Additional result-admission fixes and remaining gate

Console's `computer.log` override now preserves the shared pre-effect return preparation, including refusal before history eviction. Private memory sponsorship prepays destination links without stealing another owner's reservation; real cold tests preserve the transfer cursor and same-tick credits. This is still not universal memory enforcement.

A fresh native red test additionally reproduced `table.insert` modifying a guest table before durable result admission. `insert`, `remove` and `sort` now use the existing `prepare_return` immediately before their final table mutation. Focused tests enumerate every shorter work allowance and inject codec-storage refusal, verifying unchanged tables and exact zero/one-result arity. This does not claim resumable comparator callbacks or removal of table limits.

The original four-wall animation gate was run unchanged. It fails during initialization at `tests/monitor_animation_engine.lua:95` because the continuation compiler does not yet lower `func_proto`. No cadence/timing samples were produced: this is a missing language prerequisite, **not a measured performance failure**. Task 3.4 stays unchecked, as do full-language, aggregate memory, services and all other outstanding gates. No production-budget increase, native fallback or publication is authorized by these passing scalar checks.

## Guest-table retained-admission checkpoint

Evidence: `resume-heap-memory-01/`. The pinned engine first rejects the new assertion that an actual sandbox-created table/string must have lifetime admission; the previous implementation left both uncharged. The existing numeric continuation owner now governs table payloads, unique strings in table keys/values, ownership-index/key-vector accounting, defensive table snapshots and `rawset`/multi-target/insert/remove/sort publication. This path is exercised through the actual sandbox and compiler, not only manual ledger calls. It remains host-context opt-in until complete frame/temporary/result accounting and the real runtime setting are wired; this is not a production quota or task 2.2 completion.

`memory.acquire_all` preflights the entire table/string update before changing any record, link, reservation or ownership index. It deduplicates aliases and validates conflicting charges before commit. Shrinking records first can fund a non-growing replacement even while the owner remains above a lowered setting; the complete proof becomes temporary prepaid credit without yielding. The stronger native test exposed and fixed an intermediate bug where the per-object admission recheck incorrectly refused this already-proven replacement. No production budget was raised.

The new `tests.resource_policy_heap_memory` exercises real cross-tick guest allocations until aggregate refusal, table/string defensive copies, atomic multi-target and insertion refusal, every shorter mutation work allowance, over-limit deletion and sponsored delivery. Its cold case saves a cyclic/aliased guest graph and paid continuation after lowering its account to one byte, verifies unchanged `on_load` and same-tick retry, then reads and reduces that accepted graph and completes its effect once before teardown. The original memory, sponsorship, heap-trust, result and scalar-lane fixtures remain regression gates. A first growth-test source accidentally made its root dead: correct liveness collection reclaimed the chain, so it did not demonstrate retained growth; that failed attempt is preserved and the final source keeps its root live explicitly.

This checkpoint covers **retained table graphs only**. Private frames/slots/tuples, standalone strings, symbolic bindings, collector/validator workspace, prepared result/control reserves, transient copy peaks, committed/staged Console lifetime transfers and universal live-settings integration remain unfinished. The old per-shape guards are not removed yet. Original monitor/performance, native UI/audio/render, migrations and connected multiplayer gates remain unchecked. Overall progress stays **5/47**; no publication or completed implementation is implied.

## Initial-frame/source admission checkpoint

Evidence: `resume-frame-memory-01/`. A further native red fixture shows that an empty-event invocation can initialize its private checkpoint and execute a prepared effect with no retained frame/source admission. The continuation now prepays its initial container/header/static-slot footprint and source/handler strings atomically through the same owner **before mutating the checkpoint**. A refusal leaves the candidate checkpoint empty, the ledger unchanged and guest effects absent; raising the account permits normal invocation. Two owners share immutable source/handler payloads while paying separate frame/link metadata. The initial deterministic footprint counts twelve containers, seventeen header entries and the compiler's static local/scalar/tuple-slot ranges; it is not a claim of actual Lua heap bytes.

The collector now keeps the invocation header/source identities rooted for the continuation lifetime, including across a separate-process cold load with the account lowered to one byte. Tests assert those charges remain present through every collector/resume step, do not execute or renew credits in `on_load`, keep another owner's source alive during teardown and release exclusive records on close. This is initial static-frame coverage, **not dynamic tuple payloads, symbolic cells/bindings, temporary/compiler/result workspace or emergency control coverage**. The opt-in production boundary and all outstanding acceptance requirements remain unchanged; tasks 2.2–2.4 and 3.4 stay unchecked, with 5/47 overall complete.

## Symbolic-binding admission checkpoint

Evidence: `resume-binding-memory-01/`. Another actual engine red fails on an uncharged saved facade/method descriptor. One shared private `binding_token` path now prepays metadata work, token/descriptor/index/order storage and deduplicated descriptor strings before publishing the checkpoint entry. Both freshly encoded service facades/methods and Console graph restoration use this path. The collector's provisional footprint includes the same descriptor envelope. Existing symbolic identities, checked provider restoration and live service authority checks are unchanged; no native function is admitted into the checkpoint.

The focused fixture refuses a result whose token alone fits but complete descriptor strings do not: no token/index/link or prepared external effect is published. Raising the account resumes once without replay. A Console graph restores one shared parent/method identity through the actual guarded decoder and completes with accounted records. The real two-process cold case captures a facade and method, completes one guarded effect, lowers its account to one byte and saves inside a long loop. Load and same-tick retries preserve the paid records/counters, then the captured method executes only the remaining effect before full owner teardown. These bindings are a trusted fixture provider, **not new native peripheral/authority acceptance**; the production-context KV/Console fixture remains a separate unchanged regression gate.

Dynamic tuples, standalone strings and namespace symbols, collector/validator/compiler/service/result/control workspace, temporary peaks, Console lifetime transfers and universal settings/migration integration remain required. This does not complete task 2.2 or the original monitor/performance gate; progress remains **5/47** and the branch remains unpublished.

## Source-symbol lifetime checkpoint

Evidence: `resume-symbol-memory-01/`. Namespace/global tokens and their interned path strings now have retained admission. The existing parser/lowerer collects deterministic static source paths; a host-supplied owner prepays their tokens, strings and root-vector metadata together with initial frame admission. That source-owned pool stays rooted for the invocation lifetime, so a method first used after a settings decrease does not require fresh metadata growth. Computed paths still use atomic table/string admission before either symbol index changes. Source paths do not become executable authority: normal global/member resolution and service checks remain in force.

A diagnostic red package preserves every previous production payload and adds only `tests.resource_policy_symbols` plus its manifest hash; it actually fails on the missing source-symbol pool. The focused test covers both source forms, a computed `math.floor` alias, collection, unchanged same-tick credits, a lowered one-byte account and first use of a prepaid later method. The separate native cold heap/binding fixture now retains the computed method across its real separate-process reload as well. The growth fixture grants a fixed 4,096-byte guest-growth allowance **after** initial source metadata admission, rather than conflating the source-derived footprint with guest growth. No production allowance or acceptance deadline is raised.

This remains unfinished owner-path integration. Initial preparation is still monolithic like the existing compiler and needs task 4.4's durable cursors; temporary peaks, dynamic tuple/standalone-string/control/result workspace, Console lifetime transfers and universal live setting/migration integration remain open. The optional private symbol-root field is not a shipped migration claim. Overall acceptance remains **5/47**.

## Standalone-string lifetime checkpoint

Evidence: `resume-string-memory-01/`. Source literals now share the accepted source-root pool with namespace symbols. Their deduplicated bytes and root-vector metadata are admitted before checkpoint publication and remain live for the invocation, including literals first evaluated after a capacity decrease. Dynamic strings returned by pure helpers, prepared services or guarded indexing enter the same lifetime ledger before retention. String members of a result tuple are admitted as one complete batch rather than leaving an earlier member charged when a later string does not fit. This does not yet account the tuple containers or temporary creation peaks.

The previous production archive plus only the new fixture/manifest actually fails `standalone string retained without admission`. Both source forms now prove dynamic string aliasing, future literals, collection, same-tick no-credit-renewal and execution below a lowered account. A two-string prepared result refuses one byte short before either ledger member or external effect is published, then completes exactly once after raising capacity. The real cold heap/binding fixture additionally retains a non-table string result through its separate-process load. These are owner-path proofs, not universal memory enforcement or the original performance gate.

Source preparation remains monolithic. Dynamic tuple/container and temporary/compiler/service/collector/validator/result/control workspace, committed/staged Console transfers, universal settings and migrations remain required before enabling the owner path globally. No independent string/table caps are removed yet and no additional checklist item is accepted; overall progress remains **5/47**.

## Paid preparation progress and abandoned-prefix recovery

The stronger string-accounting path exposed a real nonprogress failure at the unchanged 1,024-credit growth gate: each collector retry revalidated its growing private workspace and consumed the slice again. Private `validate` → `collect` → `execute` progress is now retained. Header/schema/phase checks still run every attempt; the full graph proof finishes before collection, and a paused collector continues its already-paid cursor rather than restarting validation. A collection that reclaims storage yields at a private prepared boundary so a failed copy cannot repeatedly rebuild abandoned prefixes in a too-small tail; clean preparation can deliver an already-paid scalar result in the original next tick. No guest code executes during that boundary and no spent credits are renewed. Unknown phases and conflicting execute/job states reject through the existing malformed-checkpoint tests.

A read-only architecture review identified an intermediate retention regression: a partial Data copy can publish orphan child ownership records without completing any guest block. The first phase implementation kept execute readiness and accumulated those abandoned prefixes. The exact intermediate package plus only the new regression fixture actually fails `abandoned snapshot prefixes accumulated across retries`. The corrected path invalidates readiness when table/symbol/binding indices or the owner membership grow, schedules reclamation and retains only genuinely unchanged preparation. The regression bounds retained prefixes across fifty 1,024-credit retries, then completes once after full work is restored. This is reclamation safety, not a claim that the remaining monolithic copy already has a durable service cursor.

`tests.resource_policy_preparation_cold` freezes a real paid collector phase with an accepted linked-table prefix, verifies unchanged phase, cursor, ledger and ownership on load and same-tick retry, then completes the original 128-node graph and both once-only effect markers. The existing validation-cold gate now additionally checks the unchanged guest PC and distinguishes a still-collecting cursor from fully completed preparation waiting before guest execution. All original tick/work ceilings remain intact. The earlier failed growth, prefix and validation-boundary attempts remain separate from final evidence. These changes do not establish full language/service, universal memory, native rendering/audio, multiplayer or original monitor performance acceptance.

## Return-cache frame reservations (private ABI 3)

The next ownership slice accounts private tuple carriers, pending-call metadata and prepared-result wrappers as an invocation-scoped frame reservation. Each compiler-derived call site (plus the Console return site) reserves a scalar carrier; the shared active-call carrier covers status and preparation metadata. Actual arity may grow these reservations through the existing aggregate ledger; the initial carrier width is not a new tuple ceiling. High-water workspace is retained deliberately until invocation teardown, so accepted capacity remains reusable after a settings decrease without retaining obsolete tuple identities. A call clears its overwritten result cache before preparing its replacement.

Carrier growth and all string members share one atomic admission proof before prepared result publication. The new native red actually publishes one trusted fixture effect without the required tuple admission on the prior production code; the candidate refuses one byte short before that effect, leaves the frame charge unchanged, and succeeds once after raising the allowance. Tests also cover nil-containing triple results reused across slices at a one-byte allowance in both source forms, and a Console return that cannot print or commit before its carrier is admitted. This is return-cache reservation coverage, not complete temporary/native-copy peak accounting or a claim that every binding/snapshot preparation graph is already admitted as one transaction.

The tuple cold fixture freezes with a triple's prepared service result saved but caller delivery absent. It verifies unchanged capacities, ledger, nil arity and aliases in `on_load` and same-tick retry, then delivers without replay under a lowered one-byte allowance and releases the invocation owner. Malformed carrier headers/entries, source-site mismatches and carrier totals inconsistent with the authoritative frame ledger are rejected by incremental validation. A separate cold fixture pauses inside a 100-site capacity-map scan and preserves its paid count/sum before finishing validation without guest execution. The private experimental checkpoint ABI is now **3**; earlier private experimental checkpoints are refused and retained, not silently reconstructed. Public source/compiler/storage versions are unchanged. This does not satisfy the still-required migration from shipped legacy runs.

Temporary/argument/decode/snapshot peaks, full compiler/service/collector/validator/control reservations, Console committed/staged lifetime transfer and universal production setting/ownership wiring remain outstanding. Overall checklist progress remains **5/47**; this checkpoint cannot be published or merged as the completed policy.

## Scalar-local assignment hot path (private ABI 4)

Source review after the cold deadline tail found that each ordinary scalar-local update constructed the generic argument/target/decoded/staging vectors needed for multi-target publication. The lowerer now specializes only one local target with one RHS: it preserves decoded scalar validation before publication and uses the existing metered `bind(1, value)`. Shell-global and multi-target assignments retain the existing atomic path. A function RHS still executes fully and adjusts to its first result as Lua requires; control flow and safe-point positions remain explicit.

The native red records 9,000 allocation units and 34,000 work for 1,000 scalar updates after subtracting identical startup. The candidate records 1,000 allocations and 25,000 work in both source forms and both engines: discarded vectors are no longer constructed, while one canonical binding allocation and its scalar guard remain. No resource default or gate increased. Guard injection verifies refusal before the local is written; existing tuple/nil/alias/cold cases remain required.

One serial matched production-context cold pair per engine uses the identical finite KV/Console/runaway fixture and unchanged settings/deadlines. Complete wrapper times are 140.700 → 90.679 seconds in base and 143.204 → 92.919 seconds in Space Age, with every functional and clean-shutdown assertion passing. These are whole-scenario observations including creation, two cold phases, assertion/GUI-mock overhead and background actors, not isolated guest timings, representative FPS/UPS or a statistical performance guarantee. Host load was recorded; unrelated activity was not fully excluded. Earlier failed deadline evidence remains failed. The original controller/monitor performance gate still requires its actual workload and the missing function-lowering prerequisite.

The private checkpoint ABI is now **4**, because single-result versus tuple liveness at a saved assignment boundary changed. Earlier private experimental ABI 3 frames are refused with their accepted locals retained; no replay or implicit migration is claimed. Public compiler/API/storage versions remain unchanged. Overall acceptance remains **5/47**, and universal resource integration plus the complete specification are unfinished.

## Early original-workload prerequisites (private ABI 5; gate failed)

Task `t_c0c6d7f7` continues the prepared cumulative checkpoint on local branch `feature/resource-policy-early-t_c0c6d7f7`. Evidence, exact packaged candidates, source recovery and complete failed logs belong to `/home/siredvin/artifacts/tweaked-computers/t_c0c6d7f7-early/`; its `HANDOFF.md` and receipts distinguish each archive and attempt. **This is not an accepted early gate, release candidate, migration or complete language/resource implementation. No checklist item is newly checked.**

The same block backend now lowers constructors, indexed/multiple assignments, concatenation, generic iteration, nested functions, captured lexical cells, ordinary calls/returns and the required `pcall` boundary. Function identities and their cell references are private plain records; no native closure/thread or replay enters storage. Call frames return through the existing trampoline. Closure/cell/frame/result roots join ownership collection, with optional private-ledger frame admission; this does not enable universal production memory accounting. The liveness fixed point propagates new facts through predecessor edges instead of repeatedly scanning the complete graph. Core iterator/library identities have symbolic encodings, including inside temporary guest containers; Data-only and committed Console boundaries still reject executable values.

Trusted raw service results are defensively projected before recording durable success. Reviewed monitor mutations/sync selection prepay their empty result. A monitor touched by a pending program or Console invocation cannot seal a new snapshot until that actual invocation ends; already sealed fronts remain valid. The hold uses the actual principal/invocation identity, survives cold reload and becomes stale after Stop/reset/replacement without undoing accepted model writes. `tests.resource_policy_monitor` checks real production scheduling, a shared readable partial model, the unchanged prior native front, progress of an unrelated display, separate-process reload and Stop release. No graphical or connected-client acceptance follows from these headless checks.

Initial original-chart attempts exposed same-tick reconstruction exhaustion after Validate/Save/Run. Dispatch now waits rather than faulting an untouched continuation when compilation starts with previously spent credits; a reconstruction that fails a fresh slice reports recoverable inability instead of an endless retry. This is **not** incremental tokenization/parsing/emission. The exact original chart subsequently runs, but the unchanged four-walls gate fails its shared-model coherence oracle during periodic rediscovery. A separately identified forwarding diagnostic archive records tick 603: nested `plot` at depth 2, PC 549, allocations 81,868/81,920, work 343,338/500,000, compilation 458,441/1,250,000. Three models have revision 9,494 while all four native fronts retain coherent revision 9,465; the fourth model is still 9,465. Publication holds are doing their job, but allocation exhaustion splits a workload that the original acceptance requires to finish coherently. The original source, budgets, structural/wall deadlines and oracle were not changed. This is a failed gate requiring design review, **not** 360 passing intervals or a cadence/CPU success. Final per-mode/layout attempts and any additional failures are enumerated in the external handoff.

New focused fixtures cover constructor/result adjustment, indexed publication order, nested iteration, exact nested-call/lexical aliases, recursion, protected guest-table errors, nil/empty tuples, Data refusal and real cold progress. Inherited regression failures, harness misuse and an interrupted long matrix remain separate from passing retries. Host wrapper tests use mocked cadence data and do not establish engine cadence. Connected nested-handler/staged-Console joins, original monitor cold/cadence completion, matched controller/Console work/retention/tick-time/input-latency comparisons, sustained/native-client gates and full temporary/control/service ownership remain unpassed. Varargs and broader callback-taking library/protected-helper coverage, complete structural validation/migration and configurable depth/resource wiring remain incomplete. The old experimental depth guard is not a finished policy setting. Earlier private ABI 4 checkpoints must not be upgraded or discarded implicitly; no shipped-save compatibility is claimed by the ABI bump.

## Early original-workload gate passed (private ABI 6)

The interactive continuation on `feature/resource-policy-completion` starts at `a2d06dd6f5c8e2ef5b0b303d89b06c061be682d9`. Its recoverable source, complete attempts, exact archives and receipts are preserved at `/home/siredvin/artifacts/tweaked-computers/resource-policy-hot-path-2026-10-23/`. `identity-parent-source.tar` plus `identity-source.diff` reconstruct the tested source. The final input archive SHA-256 is `f2e0e3596b84215369de60931fe4a46bf0a7f234ee60961c1457b0ed9a0b277d`. `verify_early_report.py` verified all 561 matching packaged source files before this documentation update. `SHA256SUMS.json` verifies the copied evidence bundle; failed/interrupted attempts are not final passes.

The design review retained the generated-block architecture. The implementation eliminates real discarded allocations rather than changing accounting or budgets: unchanged ownership-key membership reuses its vector, append-only keys publish only after complete retained admission, peripheral method descriptors materialize on demand, local/iterator bindings and single indexed writes avoid generic target vectors, and native calls avoid a duplicate generated argument vector. Scalar validation and whole-assignment preflight remain before publication. Real guest argument vectors remain charged. The private generated-call ABI is 6; experimental ABI 5 checkpoints are refused and retained, not migrated or replayed.

Cold Console acceptance exposed an additional identity bug: comparing a restored captured method with `facade.method` failed before the captured method's first call primed the native cache. Method tokens now canonicalize by facade identity and method using a metered ephemeral index. The focused test compares both equality forms before the first call. The original Console fixture and its assertions are unchanged.

`identity-gate/receipt.json` and `early-gate-report.json` establish task 3.4 on Factorio 2.0.77/build 84539:

- Both original layouts pass in base and Space Age, with exactly 360 publication intervals per combination and maximum gap two ticks. Four-wall peaks are 451,860 work / 52,223 allocations; mixed peaks are 500,000 / 74,270. Original source, shared-model oracle, budgets and deadlines are unchanged. Full cold phase markers and normal acknowledged `/quit` exits are verified.
- The original finite Console cold fixture, actual program/Console/neighbor/Stop cold fixture and retained-heap/binding fixture pass in both modes on the exact final archive. Console graph aliases, pending commands and once-only effects survive separate processes.
- Serial matched controller controls have 600 samples and 40 input observations per mode/implementation, 200 beats, 40 changes, zero faults and zero measured input-to-effect tick latency. Baseline/candidate scheduler means are 1.362830/2.156957 ms (base) and 1.505786/2.225211 ms (Space Age); p95 values are 3.486135/6.167427 and 4.491031/8.405693 ms. Mean charged guest work increases from 10,510.651667 to 28,422.985 units. This is additional overhead, not a performance improvement.
- Separate forwarding census runs preserve the original controller and Console assertions. Each measured controller owner retains one five-entry state table with 31 unique string bytes throughout all 600 samples, in both implementations/modes; no program checkpoint or shell graph remains between these finite callbacks. `retention-summary.json` checks exact tick/owner coverage and zero net growth. This is reachable-graph measurement, not allocator/GC heap bytes or complete memory-policy acceptance. Census runs are excluded from the timing controls.
- Chart scheduler timings also regress against the recorded baseline: four-wall means are 24.753092/50.854363 ms (base) and 25.996656/50.842344 ms (Space Age); mixed means are 37.669623/91.070760 and 39.199550/93.166569 ms. The report retains all sample counts, tails and reconstruction costs. Logical two-tick cadence is not 30 real-time FPS or 60 UPS; unrelated host contention is not fully excluded. Native render/real-time acceptance remains task 11 work.

The wider regression run before the final identity fix is preserved separately: the original computer fixture still expects fatal work exhaustion, full Console coverage exposes unfinished `xpcall` support, and the desired state-capacity fixture still lacks recovery metadata. These are remaining implementation obligations, not passing full-suite acceptance. Host build/animation/maintenance tests, planning/catalog checks, strict docs/player-doc checks and OpenSpec validation pass; the docs checks use the existing isolated environment with all 16 locked package versions verified. No release, merge, migration, native UI/audio/render or connected multiplayer acceptance is implied. This closes only task 3.4; the complete policy remains unfinished.

## Language continuity and protected-handler checkpoint (private ABI 9)

Evidence is preserved at `/home/siredvin/artifacts/tweaked-computers/resource-policy-language-2026-10-23/`. The complete initial matrix (`candidate-matrix.json`) uses archive SHA-256 `bc7daef9accd84b302dd40fb36691e63a1347c64f4077b9aab3fab1cc247077e`: 33 of 37 fixtures verified in both modes, with separate-process phases and acknowledged normal shutdown checked for cold cases. Four failed fixtures are retained rather than counted as passes.

The compiler and continuation now preserve variadic parameters, nil-containing expansion, single-result adjustment and variadic constructor tails. Live variadic values join the ownership roots through cold suspension. The direct emitter forwards enclosing varargs into its private constructor factory instead of emitting illegal nested-vararg source. Together with the existing calls, cells, recursion, multiple-assignment and alias fixtures, this closes task 4.1. It does not remove tuple/source limits or complete resumable library/compiler work.

Protected-call frames now handle `xpcall`, nested `pcall`/`xpcall` passed as callable values, exact success tuples and first-result error transformations. Message handlers can themselves fail, enter nested calls, suspend and cold-resume without replaying their completed prefix. Encoded callable/namespace error values retain their guest identity; unwinding releases abandoned private frame charges. `resource_policy_functions` verifies both source forms, a suspended variadic nested call and a suspended re-entered message handler in real separate processes. The original direct runtime and full Console contract fixtures pass. Universal memory/control reserves, configurable depth and complete host-error preparation are still required; task 4.2 remains open.

The activation regression previously expected variadic source to be unsupported. It now verifies successful validation without execution and separately injects lowerer failure on fresh source keys to preserve the validation-before-retirement obligation. The old cache fixture assumed nine new plans evicted its proof; it now exercises byte-policy eviction while preserving exact warm/cold charge-prefix comparisons. Both corrected fixtures pass in base and Space Age on archive `478b698d1563456c29c38a54e5073770e1bd719f7a683c2907105e69c3ed7765`. Archive comparison verifies identical production payloads; only those two tests, inventory/evidence documentation and the package manifest differ from the matrix candidate.

The initial matrix's state-capacity fixture still fails its recovery-metadata expectation, and the computer fixture still contained the prior fatal-work expectation. Later event-policy development changes are separate candidates, not retroactively included in these language passes. This checkpoint does not establish full-policy, upgrade, native-client or connected-multiplayer acceptance.

## Event admission and producer recovery checkpoint (private ABI 9)

The continuation on `feature/resource-policy-completion` retains the earlier language work. Event-policy evidence belongs to `/home/siredvin/artifacts/tweaked-computers/resource-policy-events-2026-10-23/`; its final receipt identifies the exact tested archive, fixtures, modes and separate-process cleanup. Earlier failed attempts remain separate and are not superseded by an outer shell exit code.

Verified candidate SHA-256: `7d251e059c31a9a570446e3f3053a092e9cf15e056b1f82d8177445def03710a`. All 15 selected fixtures passed: `resource_policy_events`, `computer_contract`, `computer_cold`, `runtime_budget_engine`, `resource_policy_functions`, `resource_policy_refusal`, `runtime_contract`, `shell_contract`, `shell_cold`, `monitor_engine`, `network_engine`, `logic_engine`, `modem_engine`, `resource_policy_engine` and `resource_policy_monitor`. The receipt checks 30 mode cases and 48 separate-process cold phases with zero exits, acknowledged console shutdown and no forced cleanup. The archive's production and test payloads match the checkout; this post-test report/checklist is not part of that immutable archive. Strict documentation construction also passed. This closes tasks **5.1–5.2**, not the remaining status/warning/control-memory or full-policy work.

Event entry/byte pressure now drops only the incoming handler delivery, preserves the accepted queue/run and updates the physical computer's safe-integer loss counter. Oversized preparation produces a private publication refusal without prematurely counting an abandoned preparation; invalid authority and work deferral are not reported as overflow. Counters retain total, saturation, last tick, kind and resource reason across Stop/reset/Run and cold reload. This is the internal admission/counter implementation; settings, public status, UI and warnings are separate unfinished tasks.

Initial `start` now occupies its invocation lane directly instead of passing through the droppable event queue. A one-byte event allowance cannot erase startup. The pending invocation survives cold load without executing in `on_load`, and zero guest headroom preserves it unchanged. Dispatch stamps its event tick once, then ordinary continuation rules apply.

The producer audit covers the central timer/general-event paths and logic, topology, monitor, modem and power producers:

- A dropped one-shot retires; a recurring deadline advances once without same-tick retries. Accepted timer FIFO survives a dropped power-restoration notification.
- A dropped logic delivery retains its current observation and requests a complete resynchronization on the next accepted delivery. Modem overflow is attributed to its recipient; it does not retire that recipient or its accepted work.
- Native topology detach still revokes owned output even when every notification is dropped. The reconciliation cursor/baseline advances so the same transition is not counted again.
- Monitor touch uses central admission. Coalesced resize replacement formerly had a separate fatal overflow branch; it now prepays preparation/publication, preserves the accepted event objects/bytes on refusal and counts dropped replacements without retrying completed notification jobs. Tests cover an additional byte and an event larger than the entire lowered allowance.
- Presentation holds now depend on the registered provider's actual hold callback, not the `monitor` kind alone. The physical-network fixture's synthetic resolver correctly exercises an ordinary provider without a presentation hook; the real monitor provider keeps its invocation hold.

The native budget fixture also exposed an error-handler retry bug: unwinding a failing message handler reset its logical depth, so perpetual handler failure could continue indefinitely. Re-entry now retains depth in the private pending call and refuses recoverably before re-entering the exhausted handler, for both guest and native handlers. Program and Console regressions distinguish this finite protected refusal from a genuinely infinite handler that must suspend. The existing long-loop and allocation inputs remain unchanged; their fixture follows bounded slices with explicit test clocks, while the existing real production-tick/cold phase separately verifies live settings and spent credits. This is not a new latency/performance measurement or completion of configurable depth/control-memory policy.

`resource_policy_events` and `resource_policy_functions` are included in the packaged CI cold matrix. No source/runtime budget is raised. The original chart/client/multiplayer gates and all remaining policy work remain mandatory; no release or full implementation acceptance follows from this checkpoint.

## Still required

The initial source-site inventory is complete; the final removal/enforcement audit remains open. Settings/resources, recoverable capacity handling, non-lossy settings decreases, remaining protected-call/library/compiler/service continuity, event diagnostics, native inventories/UI, complete migration and engine matrix, actual rendering/audio and connected multiplayer remain mandatory. No production budget increase or weaker test gate is authorized by this checkpoint.
