# Tasks

Planning only. Every checkbox remains unfinished until real implementation and its stated verification pass. Use a new feature branch when apply is explicitly authorized. Keep all engine saves/logs/images outside the repository and package the candidate archive rather than testing a source symlink. Paths below are existing unless explicitly described as new.

## 1. Baseline and executable contract fixtures

- [x] 1.1 Record the actual implementation base, overlapping signal-read work and a source-site disposition for every `limit-policy.md` row; verify the inventory covers constants, hard-coded/structural guards, generated schemas, serialized validators and advertised values without changing unrelated work.
- [x] 1.2 Extend `tests/runtime_contract.lua`, `tests/computer_contract.lua` and `tests/computer_cold.lua` with desired suspension, recoverable-capacity and exactly-once side-effect cases; verify they fail for the current fatal/non-resumable behavior and preserve existing language/trust-boundary assertions.
- [x] 1.3 Capture a matched packaged baseline for current finite controller, Console and monitor workloads using the repository smoke/animation/maintenance harnesses; preserve source/archive hashes and complete output, and verify observer overhead is separated from timed runs. Add a short acceptance matrix documenting changed semantics versus unchanged regression gates.

## 2. Configurable policy and resource ownership

- [x] 2.1 Extend `scripts/runtime/budget-settings.lua`, `settings.lua`, effective limit introspection and locale for the settings in `limit-policy.md`; verify `tests/runtime_budget_engine.lua` exercises native setting changes, documented defaults/units, derived values and same-tick no-credit-renewal in base and Space Age.
- [ ] 2.2 Implement aggregate live/retained ownership accounting alongside `admission.lua`, `data.lua`, sandbox and shell graph paths; verify alias/cycle accounting, repeated cross-tick growth, copy peaks, reclamation and metadata overhead with focused contract fixtures, without per-string/table/node count gates.
- [ ] 2.3 Add recoverable resource diagnostics and reserved control/cleanup opportunity; verify full-memory paths can report status, delete data, reject growth atomically and Stop without renewing guest credits. Update runtime/player safety documentation with hard-resource versus soft-work behavior.
- [ ] 2.4 Make retained-state validators distinguish malformed data from valid data above newly lowered settings; verify lower/save/reload/read/delete/raise scenarios for application state, shell graphs, drafts, pending work and queues without data eviction or schema rejection.

## 3. Durable execution vertical slice

- [x] 3.1 Extend the compiler's accepted-source lowering with explicit frames, block positions and a host trampoline for straight-line code, locals and loops; verify a finite loop spans multiple actual ticks, an infinite loop remains stoppable, and completed primitive effects occur once using both descriptor and declaration sources.
- [x] 3.2 Persist and validate the slice's continuation graph, active source identity and paid progress; verify a separate-process cold load halfway through a KV-writing loop resumes at the next step with unchanged locals, queue order and run generation, and executes nothing in `on_load`.
- [x] 3.3 Wire the slice into program and Console scheduling with separate non-reentrant lanes and shared credits; verify a suspended program does not starve a finite neighbor or Console controls and that a suspended command preserves its staged environment. Document continuation storage and cancellation boundaries.
- [ ] 3.4 Compare the slice against the recorded baseline for work, retained growth, tick time and input-to-effect latency; preserve the evidence and verify the architecture can meet original controller/monitor gates before widening language/service coverage. A failed gate requires design review, not a hidden native/fatal fallback.

## 4. Complete language and compiler continuity

- [x] 4.1 Lower calls/returns, nil-containing tuples, multiple assignment, nested functions, lexical/upvalue cells and recursive calls into checkpoint-safe state; verify existing source/runtime tests plus cold resumes in nested calls preserve evaluation order and alias identity.
- [ ] 4.2 Implement protected-call continuation/unwinding and typed recoverable depth/memory refusal; verify nested `pcall`/`xpcall`, errors in handlers, caught resource refusal, uncaught invocation-only refusal, private suspension and explicit Stop, retaining original source locations.
- [ ] 4.3 Convert input-dependent guest library operations and iterators to bounded resumable operations where native calls cannot safely span a slice; verify concatenation, formatting, sorting/comparators, unpack/return arity, table mutation and iteration across cold reload without arbitrary tuple/table/string ceilings or hidden unmetered work.
- [ ] 4.4 Make tokenizer/parser/emission/reconstruction progress resumable while reusing Phobos grammar and validation; remove source/token/node/handler/name quotas and preserve necessary native/host-depth checks. Verify large-source validation spans ticks, invalid source preserves the active run and cache warmth cannot change success/accounting.
- [ ] 4.5 Update `openspec/api/common.md`, runtime/base-global/source/Console companions, player language docs and embedded examples for the completed execution semantics; verify API inventory/help contracts and packaged tutorial fixtures agree with the implementation, with no new guest coroutine/future API.

## 5. Event admission, loss diagnostics and non-event backpressure

- [x] 5.1 Replace `computer.publish_event` overflow faults with drop-newest entry/byte admission and durable counters; verify at-capacity, one-byte-over, oversized-single-event, multiple-handler and same-tick cases preserve queue order, registrations, state and outputs.
- [x] 5.2 Audit timer, logic, topology, monitor, modem and power producers for preparation/refusal paths; verify each dropped delivery is counted once, one-shot timers retire, recurring deadlines advance, initial start cannot disappear and independent fail-safe cleanup still executes.
- [ ] 5.3 Add `computer.getResourceStatus()` and host-backed workspace pressure/loss display plus rate-limited warnings; verify counter persistence across Stop/Run/reset/cold reload, warning eviction, native integer saturation and operation under full queues without recursively enqueueing warnings.
- [ ] 5.4 Implement explicit non-event admission/backpressure for Console ingress, activation jobs and pending host operations; verify no accepted command/write is silently dropped, refused new input remains editable, and cancellation/reset/replacement releases only the correct owner's resources. Update queue/event API and player recovery documentation.

## 6. Native circuit reads and logic output

- [ ] 6.1 Remove logic input/filter/name/output-slot gates in `scripts/services/logic.lua` and downstream generic transfer/snapshot paths; verify native red/green inventories at 64, 65, 150 and more than 1,024 identities reach bulk/scalar APIs completely under adequate resource settings, including negative counts, qualities and recipe identities.
- [ ] 6.2 Make baseline/filter/sample/change preparation resumable without retiring runs on work deferral; verify initial, changed, disappearing, disconnected, power-resync and dropped-delivery-resync cases in packaged logic fixtures across cold reload.
- [ ] 6.3 Route inspector reads through complete native snapshot acquisition and resource-governed UI construction; verify the actual full client displays every signal in a 150-signal network, preserves red/green freshness and scrolling, and changes no output ownership or program subscription.
- [ ] 6.4 Preserve atomic native-capacity output writes and cleanup across suspension; verify writes beyond the old 64-slot ceiling where supported, concurrent ownership, failed replacement, native count validation and actual stop/power/path-loss cleanup. Update logic API, Reference and runnable controller examples in the same milestone.

## 7. Discovery, configurator and recipe inventories

- [ ] 7.1 Replace fixed graph/witness/find counts in `scripts/network.lua`, `services/peripheral.lua` and configuration targets with complete resumable proofs; verify old boundaries plus larger cyclic networks, both-color isolation, changing paths during suspension and no stale-authority commits in network fixtures.
- [ ] 7.2 Remove invented schema/cardinality/string guards in configuration adapters/sections/validation and `tools/configuration_catalog.py`; regenerate contracts and verify `python tools/configuration_catalog.py --check` plus native fixtures beyond old section/filter limits where the engine permits them.
- [ ] 7.3 Implement staged configurator mutation/revalidation and complete inspector enumeration under resource policy; verify competing writers, protected/nonmanual/shared groups, rollback/recovery records and no partial UI totals across save/reload. Update Configurator API and in-game guidance.
- [ ] 7.4 Remove Recipe Searcher's 50-match and downstream shape ceilings while preserving complete sorted records; verify 50/51/larger matches, category/force metadata, large products/ingredients, pause/reload and native errors using recipe data/engine fixtures. Update API, player docs and examples to replace the old cardinality-error workflow.

## 8. Modem and speaker resource-governed services

- [ ] 8.1 Remove modem channel-count/candidate/delivery/transmit ceilings and expand channel validation to safe nonnegative integers; verify old boundary crossings, shared channel state and unchanged force/surface/tier restrictions, with API/Reference documentation updated.
- [ ] 8.2 Implement save-safe prepared broadcast plans and delivery cursors; verify more than eight deliveries, receiver overflow, authority/power changes, cold reload after a delivered prefix and no duplicate transmission. Preserve observable loss attribution and no sender acknowledgement/retry contract.
- [ ] 8.3 Remove speaker catalogue/name/note/submission-count gates while retaining native domains and complete paged discovery; verify oversized catalogue fixtures, configurable page size, waiting-before-submission, native failure and no duplicate audio after cold load. Update speaker API/examples and test boolean success separately from audibility.

## 9. Monitor resource accounting and coherent continuations

- [ ] 9.1 Retain configurable monitor-axis maxima of six while removing world tile/cell/write/frame count gates and allowing resource-admissible positive finite scale; verify all existing rectangular/orientation cases, settings decreases without data loss, former scale boundaries and safe refusal before invalid geometry/model mutation.
- [ ] 9.2 Add optional named synchronization groups without fixed reference/member/group counts; verify legacy default calls, more than four members, multiple disjoint groups, duplicate-path canonicalization, conflicting ownership, atomic replacement and cleanup of all principal-owned groups. Update terminal/buffering/network API docs together.
- [ ] 9.3 Account model/front/staging/retired/native-object resources by actual lifetime and introduce invocation-aware snapshot sealing; verify suspension after partial drawing never seals a misleading completed callback frame, prior fronts remain coherent and Stop releases publication holds without rolling back accepted models.
- [ ] 9.4 Preserve atomic group publication with configurable commit admission and actionable impossible-commit blockage; verify mixed geometries, concurrent writers, lowering/raising settings, cold reload in every presentation phase and fairness to unrelated displays using existing monitor state/presentation fixtures.
- [ ] 9.5 Run packaged animation gates for both `four-walls` and `mixed`, then actual-client recordings/sustained runs per AGENTS.md; inspect frames, verify normal process exits and document renderer/provenance. Do not raise production budgets or weaken cadence gates to conceal continuation overhead.

## 10. KV exception, lifecycle and UI retention

- [ ] 10.1 Wire every retained KV-specific limit to settings and effective introspection; verify command atomicity, expiry, full browser access, over-limit read/delete/non-growing writes and lower/save/reload/raise behavior using KV fixtures. Update KV API, settings tooltips and examples.
- [ ] 10.2 Remove registry/active-device/session/helper/method/hook/blueprint/cloned-port count gates and use resource-accounted incremental lifecycle work; verify larger-than-former-bound factories, native radar/speaker preservation under pressure, deterministic adoption and no duplicate identities or orphan helpers.
- [ ] 10.3 Preserve accepted computer/KV contents in data-bearing items without independent mod transport ceilings; verify maximum accepted and grandfathered over-limit mining/replacement, absolute expiry, clone/blueprint isolation and failure without data loss. No continuation or live ownership may transfer into a replacement identity.
- [ ] 10.4 Remove fixed draft/source/search/binding/log-field length gates and expose configured retention/status through existing UI; verify more than eight drafts, full storage refusal without silent draft loss, selectable complete diagnostics, log eviction indication and stable focus/scroll in native editor/inspector clients. Keep the separate Ctrl-click fix out of this scope.
- [ ] 10.5 Implement/version synchronized migration from supported legacy waiting runs, shell graphs and device state; verify actual pre-change saves and fresh saves retain source revisions, run identities, queues, timers, outputs, KV and display state without startup replay. Document backup-based rollback and explicit unsupported-schema recovery.

## 11. Integrated acceptance and handoff

- [ ] 11.1 Complete the source-site limit disposition audit and compare settings, effective `getLimits()` output, generated schemas, API docs and tests; verify no removed capacity remains as an indirect guard and every retained resource ceiling has a setting and stated failure mode.
- [x] 11.2 Run `python tools/test_build.py`, `python tools/test_monitor_animation.py`, `python tools/planning_examples.py --check`, `python tools/configuration_catalog.py --check` and the repository's strict docs/player-doc checks; verify packaging contains the revised contracts/examples without game distributions or evidence files.
- [ ] 11.3 Execute the full affected packaged fixture matrix from `.github/workflows/ci.yml` in base and Space Age, with production-context cold/upgrade checks where applicable; verify completed markers, zero exits, retained state/effect counts and exact tested archive/source hashes, preserving full failed logs separately.
- [ ] 11.4 Exercise connected multiplayer late joining during a suspended nested handler, staged Console command, partial broadcast and render preparation; verify equal post-join state/effect order and no replay/desync. A headless-only or single-client run does not satisfy this gate.
- [ ] 11.5 Run actual-client overload UI and audio/render acceptance, plus serial matched baseline/candidate contention measurements; verify controls remain usable, dropped events are discoverable, finite workloads progress and calibrated defaults preserve original acceptance workloads without unsupported GPU/UPS claims.
- [ ] 11.6 Review source, scenario coverage, ABI migration and documentation together; deliver a verified feature branch/PR handoff only when explicitly authorized by the apply workflow, with remaining risks and evidence paths. Verify `git diff --check`, no tracked `gameitself` content and no player-data modifications before handoff.

## Workflow follow-up

- Obtain review and implementation authorization separately; this proposal does not unblock existing Kanban work or start execution.
- Reconcile and synchronize all changed capability/API companions before archiving the implemented change; do not leave former fatal/non-suspending or fixed-capacity contracts authoritative.
- Merge/release only through the separately authorized repository workflow after exact-head validation. Archive is not an implementation checkbox.
