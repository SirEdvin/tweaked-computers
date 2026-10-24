# Design

## Context

See `proposal.md` for motivation and approved scope. The source baseline is `69e27d9`, not an assertion about concurrent worker branches. The user's modified `openspec/config.yaml` is pre-existing work and is not part of this change.

Original baseline architecture (not the current partial implementation):

- `scripts/runtime/compiler.lua:318–410` uses the existing Phobos tokenizer/parser, emits instrumented native Lua, reconstructs a fresh environment for each dispatch and runs the whole handler through one protected call. It has no saved program counter or continuation frame.
- `scripts/runtime/sandbox.lua:25–58` poisons execution on work/allocation exhaustion. Guarded operations and source locations are useful reuse points, but exception unwinding loses the native call stack.
- `scripts/scheduler.lua:119–157` removes the event before execution and faults on failed execution. Program and Console share per-computer dispatch opportunities; maintenance already uses resumable cursors in several services.
- `scripts/runtime/computer.lua:120–148` prepares copied events and faults the whole run on queue overflow. State writes preflight aggregate bytes/nodes before mutation. `scripts/runtime/data.lua` overlays independent node/string/table/default-copy bounds.
- `scripts/runtime/shell.lua` stages a scratch graph and supports symbolic saved peripheral bindings; it explicitly has no continuation. This existing binding/identity model is reusable, not a reason to expose saved functions.
- `scripts/services/logic.lua` already uses the native signal API; the 64-signal gate and downstream copy/sampling paths cause the user-visible failure. Native reads do not intrinsically need a guest-facing asynchronous API.
- `settings.lua` and `scripts/runtime/budget-settings.lua` expose only five work settings. Device-specific tables and generated configuration schemas add many other ceilings. `monitor-model.lua` and the presenter mix actual geometry with unrelated world/frame/group counts. KV's `L` table centralizes the explicitly retained exception.
- Existing runtime, source, Console, speaker and monitor specs forbid suspension or assume callback completion within a tick. Existing tests deliberately assert fatal admission and queue overflow. Those assertions must change, not merely be disabled.

The requirement for exact pause/resume across cold save/load and late joining supersedes the old non-suspending/no-VM restriction. This design chooses one compiler-generated continuation path, not a native fast path plus an interpreter fallback. It is an architecture change authorized by the clarified behavior, not claimed as necessary merely to read 150 signals.

The simplification review preserves that handler contract but removes durable compilation. The partial implementation's separate compiler machine and its unresolved saved-executable-state proof are not prerequisites to complete this revised change. Existing evidence describes earlier candidates, not acceptance of the revision.

## Goals / Non-Goals

**Goals**

- Keep supported guest source, return arity, aliasing, authority and device behavior recognizable while changing scheduling and overload semantics explicitly.
- Consolidate capacity policy around actual resource owners and lifetimes. Retain necessary native domains and only the approved device-capacity exceptions.
- Preserve accepted data, committed effects and deterministic progress across ordinary saves, setting changes and migration.
- Reuse compiler front end, runtime services, identity checks, existing UI and acceptance harnesses where they remain correct.

**Non-Goals**

- No new peripheral families, filesystem, guest coroutine/future APIs, general-purpose Lua compatibility or operating-system layer.
- No automatic increase of configured budgets to hide infeasible work. No claim that arbitrary workloads fit any finite machine or that every opaque engine call can be interrupted.
- No change to force/surface/wire roles, power rules, native signal numeric domains, 16-color encoding, KV command semantics, or physical device progression.
- No automatic task unblocking, publication, merge or release from this planning change. The Ctrl-click recovery fix remains separate.

## Decisions

### 1. One policy registry; account resources rather than result shapes

Extend the existing settings definitions/effective-limit path rather than introduce another settings subsystem. `limit-policy.md` is the disposition and setting manifest. Numeric defaults for existing retained budgets/KV limits initially stay recognizable; new aggregate defaults are explicit provisional tuning, verified before shipping.

Use aggregate per-computer live-memory accounting, explicit application/shell/draft storage, shared host retained-resource accounting and queue/retention allowances. Track ownership of tables, strings, frames, service snapshots, compiled artifacts and native render objects for their lifetimes. Charge shared/aliased objects once within an owner graph; cross-boundary defensive copies have a new owner and charge. Include metadata overhead; document that units are deterministic accounting, not actual heap bytes. Host/native transient peaks need measured headroom, not an unsupported precision claim.

Use one accounted-byte ceiling per event queue or Console history, including nonzero entry/envelope metadata; remove their independent entry counts. Separate accounts require a distinct failure mode or lifetime: transient guest memory is not durable application storage, disposable logs are not drafts, and per-computer fairness is not world safety. Owner subaccounts are usage diagnostics, not additional quotas. Do not replace necessary lifetime accounting with per-tick allocation credits.

Remove fixed signal/recipe/table/node/name/source/graph/registry/method/hook counts instead of replacing them with giant constants. Remove unnecessary depth limits when iterative processing removes their host-stack risk; any remaining recursive-host protection is configurable and checked before recursion. No fixed count of computers may gate creation of a work-ledger entry.

Alternative rejected: make every existing magic number configurable. That retains the same layered refusals and violates the request to remove unjustified limits.

### 2. Compile to resumable blocks with explicit save-safe frames

Reuse the accepted language parser and validation rules. Lower accepted source into generated native Lua blocks whose boundaries return a private scheduler outcome and a save-safe next position. A host trampoline executes admitted blocks rather than keeping an unpersistable Lua stack alive between ticks. These are compiler-generated continuation blocks for this restricted language, not interpretation of arbitrary Lua bytecode and not a second fallback runtime.

Each unfinished invocation retains its active source revision/run or shell-session principal, dispatched event/command, block/function identity, logical frames, local slots, tuple arity including nils, lexical cell graph, guest heap and pending host-operation record. Values refer to heap/cell identities; callable guest values refer to validated source function identities and captured cells. API bindings use existing symbolic identity/channel/generation descriptors. No Lua closure, thread, iterator function or native entity enters the checkpoint.

Safe points bound execution, not every scalar instruction. Admit small straight-line blocks together where their work and growth can be conservatively bounded, preserving source locations, evaluation order, committed prefixes and protected-error behavior. Keep admission before effects, growing allocations and input-dependent/native work; loops and guest callbacks cannot evade interruption. Split an artificial block that cannot fit a full slice; only genuinely indivisible runtime work may refuse for that reason. No separate optimized runtime or fallback interpreter is required. Explicit iterator state preserves reload progress; no native iterator closure is saved.

Within one execution lane only one invocation is active. Program and Console each retain a lane and share the per-computer ledger/fair scheduling; a paused program does not permanently exclude Console diagnostics, and a paused command cannot publish its staged scratch graph. Stop/reset use host control, not queued guest callbacks. Work suspension is private control; capacity errors follow ordinary protected-call paths. Reserve a small accounted error/control workspace so reporting full memory does not itself require unsafe growth.

A successful external effect and advancement past that effect occur in the same synchronized atomic host step. Save boundaries cannot record the effect without its completion marker. A cold load reconstructs executable code from validated active source, not caller-supplied generated text; any ephemeral cache changes performance only, never state or accounting. Persisted logical code references carry a versioned ABI and are validated before use.

Validate at the relevant boundary: guest input, restored/imported records, executable reconstruction and live effect authority. Trusted mutations maintain private invariants; a normal suspension alone does not justify revalidating the whole unchanged graph. Reuse private admitted snapshots/results rather than encode, decode and recopy them at each layer. A saved readiness flag is not proof of validity; cold load and joining peers still validate safely with deterministic admission. Collection for reclamation is distinct from schema validation, and remains bounded and metered. Internal assertions preventing ledger corruption or unsafe effects are not blanket deletion targets.

Alternatives rejected: native coroutine-only suspension cannot meet the save-safe frame contract; restarting a handler and skipping writes cannot preserve arbitrary locals, reads or effects; retaining the old fatal path as a silent fallback contradicts the approved behavior.

### 3. Bounded compilation; resumable host services

Reuse the existing front end in a bounded, non-resumable compilation pass, including reconstruction. Meter input-dependent parser/emitter work and allocation, retain real host-stack/native-domain checks, and pre-admit indivisible native loading. Remove independent source/token/handler quotas, not resource enforcement. A request may wait before a pass starts; the pass then completes or refuses recoverably. It must not retain tokenizer/parser/emitter frames, generated-text authority or a second compiler VM. Do not repeatedly retry an impossible compilation each tick.

Retain the exact requested source, revision and request status, not partial compiler execution. Invalid or over-budget candidates preserve the previous active run and editable draft. On reload, rebuild executables from source under the same bounded policy; a reconstruction refusal preserves the suspended handler and committed state, reports recovery guidance, and runs no guest code. This deliberately gives up eventual compilation of every source that could fit across many slices. Lowered limits may require raising the applicable setting before reconstruction can succeed. Cache warmth must not change accounting, scheduling decisions or results between peers; never trust saved generated text or completion flags.

Reuse existing service operations behind private prepare/commit records. Expensive traversal, sorting, copying, hashing/serialization and renderer preparation advance in bounded chunks. If `table.sort` or another opaque helper calls guest callbacks or has input-dependent native work, use a resumable equivalent under the same API semantics; do not merely surround a monolithic helper with two cheap counters.

Capture native signal data once for a coherent observation; snapshot conversion and canonical ordering then resume over that frozen data. For topology, maintain a visited set/frontier and invalidate/revalidate proofs after changes, including final live authority checks. Native recipe inventory candidates can be captured once; do not scan unrelated prototype universes to establish a signal or recipe capacity.

Mutations prepare privately and revalidate current identity, power, authority and relevant state at commit. A prepared KV/configurator candidate cannot overwrite intervening updates from another writer. Return values remain ordinary sequential arrays/maps, not lazy proxies or guest futures. Inspection has its own read-only job owner under host work/memory accounting and never uses an arbitrary guest result-count ceiling.

Truly indivisible native calls cannot be paused internally. Charge their declared/proven work before entry, bound preparatory work, and report recoverable inability when the full configured slice cannot accommodate them. Native-call time and transient memory remain empirical risks to measure. Do not turn “retry next tick” into permanent nonprogress for an atom larger than every available slice.

### 4. Queue admission and event-drop accounting

Change event publication centrally, then audit all producer paths: timers, logic samples, modem deliveries, monitor touch/resize, topology notifications and power restoration. Validate event shape/authority; reserve envelope/metadata and admission before full copying where possible. Accounted-byte overflow—including one event larger than the queue allowance—drops that newest delivery, increments the receiving physical computer's persistent counter and retains accepted queue order. Empty events still consume metadata bytes; no entry-count ceiling is needed. A work shortage is resumable preparation, not queue overflow.

Warnings are rate-limited logs backed by durable counters; they never enqueue a warning event. Diagnostic storage is reserved. Counter saturation uses the exact-integer domain and an explicit flag. One-shot timers retire even if their delivery is dropped; recurring timers advance normally and keep missed-interval semantics. Initial `start` is lifecycle execution, admitted directly rather than vulnerable to event-queue loss.

Logic sampling retains complete current baselines; a lost delivery marks the next admitted event as resynchronization with a complete current snapshot. Intermediate pulses remain unobserved, never fabricated. Host fail-safe revocation executes independently of whether its notification was delivered.

Modem preparation reserves its payload and deterministic route plan before accepting transmission. Delivery cursors persist after each recipient; accepted prefixes are never retransmitted. Live recipient authority is rechecked, with overflow/unavailability recorded as explicit loss. This deliberately changes the old all-in-one-tick fan-out behavior without adding acknowledgements or sender retries.

Non-event work is never casually dropped. Full Console ingress visibly refuses before acceptance with input retained. Coalescing applies only to superseded read-only refreshes or explicitly replaceable presentation snapshots, not committed writes, drafts or pending accepted commands.

### 5. Monitor and KV exceptions, without duplicated transport gates

KV keeps its dedicated capacities and defaults as settings. Preserve atomic writes, exact TTL semantics, complete browser access and item transport. Derive compatible admission headroom from KV snapshot settings and actual metadata; lower settings grandfather accepted data. Reads and reducing operations cannot be blocked merely because contents exceed new-growth policy.

Monitor geometry remains capped at six tiles per local axis. Axis settings may reduce new grouping dimensions; setting changes alone do not silently regroup/clear existing displays. Keep physical identity and normal explicit geometry-change clearing rules. Expand scale to positive finite representable values under aggregate resources; the old range/step was not a native capacity constraint. Color/glyph encoding remains unchanged.

Remove fixed group/reference/member counts and allow optional named groups while preserving the no-key default API. One display still belongs to at most one selected group because two publication barriers conflict; this is ownership/semantic validation, not a resource quota. Track model/front/staging/retirement memory through the shared resource owner instead of separate arbitrary cell/frame counts.

The existing complete-frame guarantee cannot use every budget slice as “callback finished.” Keep already sealed snapshots valid, but do not seal new snapshots of displays modified by unfinished invocations until those invocations complete or terminate. Successful model writes remain shared and readable immediately. An infinite producer can therefore hold affected publication until Stop; unrelated monitors continue. Explicit Stop releases the hold and makes prior successful model writes eligible under normal buffering. Group status identifies this wait rather than claiming rendering is finished.

Whole-group visibility publication remains atomic in one tick. A group whose unavoidable commit exceeds the full effective budget is observably blocked with recoverable setting guidance; never split the publication, add an undocumented count ceiling or exceed the budget. Preparing many frames across ticks does not prove the final commit fits.

### 6. UI and API migration are part of the behavior change

`api-contract.md` defines proposed resource errors/status and `getLimits()` policy version 2. Device API companions spell out affected signatures and fields. Removed numeric limits disappear from introspection; do not advertise `0` or infinity where consumers expect finite capacities. Preserve successful service result shapes and both saved source forms. Add one runtime status method and optional monitor group key arguments, not a new control framework.

Reuse existing workspace status, Console and inspector layouts. Show budget waiting separately from real faults, surface recoverable refusal with setting guidance, and retain event-drop counters outside rolling logs. Keep Stop reachable, preserve typing/scroll/selection, and bound GUI construction through viewport/paging and scheduling without limiting inventory completeness. Update localized settings/tooltips, packaged API docs, Reference and runnable examples together.

## Risks / Trade-offs

- [Overengineering returns through internal checks] → Each retained limit/check identifies the resource, trust boundary, native/API invariant or concrete data-loss risk it protects. Delete duplicated enforcement after tracing every consumer; iterative traversal removes host-depth limits only after downstream recursive paths are addressed. Scheduling batch sizes and paging are implementation tuning, not inventory refusal caps.
- [Compilation no longer spans work slices] → Recoverable refusal preserves drafts, active runs and suspended frames. Measure worst-accepted cold compilation/reconstruction and verify deterministic warm/cold behavior; do not claim a compiler cursor is necessary to preserve running handlers.
- [Runtime compatibility and continuation overhead] → First implement a real vertical slice covering nested calls, closures, protected errors, a completed side effect, suspension and cold resume; compare matched baseline/candidate workloads before widening coverage. No fallback to fault-on-budget if it fails.
- [Memory accounting misses aliases or transient peaks] → Ownership-ledger tests, cyclic guest/Console graphs, copy-on-write peaks, cross-tick retention and actual engine stress evidence. Guest Data restrictions and continuation graph encoding are separate.
- [Very small budgets cause nonprogress] → Distinguish transient exhaustion from impossible indivisible admission; show the effective setting and needed work. Retain reserved control/cleanup service and deterministic fairness.
- [Raised budgets can degrade UPS or exhaust host memory] → Explain accounting units and practical tuning; calibrated defaults are not engine maxima. Keep safety settings positive, not accidentally unlimited.
- [Yielding changes observation timing] → Re-read tick/authority on resumed operations, preserve captured event/sample timestamps and coherent read snapshots, and test competing writers across yields. A handler is not a transaction.
- [Saved continuation code injection or stale bindings] → Versioned validated plain records, reconstruction from source, symbolic capabilities and live checks before effects; malformed saves preserve recoverable user data but do not execute.
- [Atomic group commit and infinite producer hold] → Explicit visible blockage and control actions; no partial frames or false eventual-success promise when the producer never finishes or configured atomic capacity is insufficient.
- [Event drops change automation behavior] → Durable counters, rate-limited warnings, full logic resync, no silent prefix data, and independent authority/output cleanup.
- [Scope overlaps active Kanban work] → Rebase against actual landed code at apply time and reconcile narrowly; this plan does not supersede or unblock cards by itself.

## Migration Plan

1. Start implementation on a new feature branch after explicit apply authorization. Record exact baseline and pending overlapping work without changing unrelated edits.
2. Introduce versioned resource policy/checkpoint data with migration for legacy waiting runs and shell graphs during permitted synchronized lifecycle stages. Preserve active source, run identity, state, timers, queue order, outputs and spent ledgers. Legacy native handlers cannot be saved mid-call, so do not invent missing frames.
3. Persist paused handler continuations and necessary pending host jobs as ordinary validated data, but only source/revision/status for compilation requests. Load performs no execution, no source replay and no ledger renewal. Discard partial compiler-machine state without discarding its source or the previous active run; it is not executable authority. Reconstruct ephemeral executables only during synchronized bounded compilation. Cold and joining peers must agree on logical progress regardless of cache warmth.
4. Replace fatal resource transitions only after shared helpers and producer paths follow the new recovery contract. Remove each independent ceiling end to end, including serialized-record validators, generated schemas, UI, docs and fixtures. Keep KV/geometry exceptions and real safety validation.
5. Verify upgraded and fresh saves in base and Space Age, data-bearing mining/replacement, accepted-over-limit settings decreases, actual GUI/rendering, and connected multiplayer late joining with a suspended invocation. Deliver exact archive hashes and evidence separately from planning validation.
6. Rollback uses a pre-upgrade save and matching prior archive. Do not load a new continuation schema into an old runtime or imply that downgrading code can deserialize new frames. No destructive automatic downgrade, reset or source rewrite.

Verification preserves configured budgets, result/effect ordering, admission bounds, atomicity, no replay and the original controller/monitor workloads. It does not require a revised implementation to reproduce an older implementation's internal guard sequence or charge trace. The current implementation's warm/cold deterministic charges remain binding. Task 3.4 requires a measured baseline comparison and its stated gates, not an invented baseline-speed-parity threshold; real regressions remain explicit release-review evidence. No new performance claim follows from this design revision.

## Open Questions

Only tuning remains: calibrate provisional aggregate-memory/cache defaults and deterministic accounting weights against measured retained peaks and matched workloads. This must not change the approved categories, overload semantics, source compatibility or acceptance gates; a demonstrated incompatibility requires review rather than quiet scope reduction.
