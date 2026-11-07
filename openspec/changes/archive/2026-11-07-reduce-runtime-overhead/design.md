# Design

## Context

See `proposal.md` for the motivation and compatibility decision. This design changes the cost of existing native execution, not its execution model.

Observed paths in the current source:

- `scripts/runtime/compiler.lua:356` validates an exact-source proof, creates a sandbox, initializes APIs, and loads fresh guest functions for each callback.
- `scripts/runtime/sandbox.lua:6` creates guard closures and private ownership tables for each invocation. These tables contain mutable authority and cannot be shared.
- `scripts/runtime/sandbox.lua:654` formats program print output, then calls the guarded computer log service. Console print already has a private output callback.
- `scripts/runtime/computer.lua:23` charges text length plus retained-entry count squared. It removes old entries from the front of the saved array repeatedly.
- `scripts/runtime/shell.lua:125` also includes squared log-count charges in command overhead. Changing only the buffer writer would leave this separate cost.
- `scripts/runtime/admission.lua:34` selects a budget by string and validates context and amount on each reservation.
- `scripts/services/peripheral.lua:94` already retains callback-local inventories and availability data. It replays discovery charges and invalidates proofs before providers without `callback_stable`.
- `scripts/runtime/compiler.lua:107` emits guarded expressions. Statement, function-entry, loop, and call paths add further checks.

The local baseline and attribution bundles named in the proposal are separate evidence sets. Nested attribution timers overlap and add overhead. They identify candidates, not measured optimization gains. They do not establish the cost of the user's save, open Console, or modpack.

Existing specifications require every API operation to recheck authority. The proposed runtime and network deltas replace that mechanical rule with current authority plus narrowly bounded proof reuse. The source and Console deltas preserve their distinct execution and retention rules.

## Goals / Non-Goals

Goals:

- Remove redundant host work without giving guest code a less restricted entry point.
- Make repeated logging proportional to actual formatting and retention work.
- Keep accounting deterministic with cold or warm host machinery.
- Retain fresh guest state while reusing immutable host implementation code.
- Make each removed check traceable to an earlier proof, a private invariant, or a prepaid bounded region.

Non-goals:

- No new VM, interpreter, continuation, coroutine, or persistent guest environment.
- No increased resource ceilings, removed Console entry limit, new policy setting, or unsafe mode.
- No change to timers, queue scheduling, active subscription cadence, or background maintenance ownership.
- No removal of Data validation, native availability checks, output-owner cleanup, or exact return contracts.
- No promise about multiplayer performance or the user's actual save from isolated headless timing.

## Decisions

### 1. Bind one private output sink to admitted execution

Use the existing runtime buffer writer rather than add another output service. At dispatch, bind its destination to the admitted computer and exact program run or shell session. Keep this binding private to the guard.

Program `computer.log` performs its exact arity and string checks. `print` performs bounded safe formatting and preserves nil positions, tabs, and zero return values. Both routes then use the same checked sink. Neither route sends an already validated string through the generic Data service bridge.

Retain the fatal-control check and execution retirement checks. A local append does not require a repeated physical owner discovery while its admitted proof remains valid. An invalidating host boundary retires or refreshes the owner proof before later output. Guest code cannot provide or replace the destination.

Prepay the complete entry, formatting allocations, retention work, and the zero-result call contract before append or eviction. In particular, `prepare_return` and service-result accounting must not first refuse after the entry has been published. A smaller route must preserve this existing protection.

Console keeps its command prefix and its documented ignored-extra-argument exception for `computer.log`. Program logging keeps exact one-argument validation. The complete prefixed text must fit before any retained history changes. Separate host fault diagnostics retain their existing bounded path.

Alternative rejected: remove the guard from a guest-visible service. That would permit forged destinations, post-fatal effects, or publication before result admission.

### 2. Compact one expired log prefix

Preserve `rec.logs`, `rec.log_bytes`, entry `{text,tick}` records, and `rec.log_truncated`. Do not introduce a ring-buffer schema or persisted cursor.

For an append that already fits, perform constant retention work. Otherwise, admit a conservative linear allowance before scanning or changing the retained array. Determine the minimum prefix whose removal satisfies both existing limits. Move the surviving entries once, clear the obsolete tail, and append the new record.

Derive the linear allowance from the bounded prefix scan, survivor movement, tail clearing, and fixed publication writes. Charge formatting and string construction separately where they actually occur. A string type or length check is not itself a byte-copy operation.

Update the shell's command echo/error reservation as well as the guest append path. Preserve its prepaid recovery diagnostic and cleanup capacity. Host-only callers that omit a guest spender still use the same bounded retention algorithm.

Refusal must precede mutation. A failed guest append preserves entry identities, order, bytes, ticks, and truncation state. A later host diagnostic remains a separate permitted append.

Alternative rejected: repeated `table.remove(...,1)` with a lower charge. That changes admission but leaves the avoidable array shifts intact.

### 3. Specialize admission without another ledger

Keep the synchronized ledger as the only source of spent credits. Bind its machine and ledger references after validating the execution identity and tick. Add narrow work/allocation reservation paths used by the guard; retain checked generic ingress for untrusted or general host callers.

Remove repeated kind selection and validation of constants already established by private code. Validate variable amounts at the boundary that derives them. Preserve safe-integer, nonnegative, overflow, and stale-context rejection.

Do not store a second remaining-credit counter. Do not cache mutable settings, aggregate totals, or maintenance spending as invariant values. Read those values at reservation boundaries, unless a reviewed non-reentrant region proves they cannot change. Refresh invocation-bound state at the next dispatch.

Combine reservations only for a bounded unit with no earlier observable effect inside it. Admit both required work and allocation before publication. Previously paid units remain spent after later refusal. The new charge sequence can differ from the old sequence; cold and warm execution of the new version must agree exactly.

Keep compilation-cache replay consistent with the revised cold path. A cheap host implementation must not make cache hits free or reset shared maintenance headroom.

Alternative rejected: raise budgets or discount reservations without removing work. Neither demonstrates lower host CPU cost.

### 4. Share implementation code, not invocation state

Move stateless implementation functions and immutable descriptions out of `sandbox.new` where this removes repeated construction. Pass invocation context explicitly to shared host implementations. Keep only the thin per-invocation adapters required by the existing compiler and public calling convention.

Retain fresh guest functions, namespaces, private bindings, ownership maps, call/service frames, counters, source coordinates, and fatal sentinels. Do not use a mutable module-global current guard. Do not retain an entire callback environment or cached guest closure graph.

The existing private-helper rebinding regression in `tests/runtime_contract.lua` is an acceptance gate. Add interleaved program/Console and cross-computer cases, including a failed invocation followed by a healthy one. Alias identities within one invocation, including `unpack == table.unpack`, remain unchanged.

Alternative rejected: cache the whole environment. A callback can rebind a private local helper, so environment reuse would change later behavior.

### 5. Extend the existing callback-local proof mechanism

Use the proof lifetime already present in `scripts/services/peripheral.lua`. Do not introduce a global positive-authority cache or background authorization snapshot.

A proof records its exact owner, generation, force, surface, selected color, physical witness, and logical target identity. Each call still verifies the binding it requests. Reuse only the physical checks whose assumptions remain valid. Keep native radar/speaker availability, method restrictions, and target-specific checks at use.

Classify the actual service boundaries before enabling reuse:

| Boundary | Proposed treatment |
| --- | --- |
| Private local formatting and buffer append | Retain the admitted owner proof; enforce fatal control and output admission. |
| Pure guest computation | Retain physical proofs; preserve guest value, allocation, tuple, and depth checks. |
| Existing reviewed `callback_stable` monitor provider | Reuse only its established physical invariants; retain geometry, target, and publication checks. |
| Other service providers or native callbacks | Keep current invalidation unless source and tests establish each invariant. |
| Stop, fault, reset, replacement, or owner retirement | Discard invocation authority before later effects. |
| Return, next callback, next Console command, or cold load | Create a fresh invocation proof; retain no executable permission. |

For each enabled provider, document the preserved facts and the operations that invalidate them. Invalidate before the potentially changing operation, even if it later throws. If a proof cannot be established, keep the full check and existing fail-closed result. This is a conservative default, not an invitation to mark every provider stable.

Alternative rejected: treat non-yielding execution alone as proof that every host call is harmless. Host providers and test adapters can change physical state or raise callbacks.

### 6. Coarsen only prepaid, finite compiler regions

Keep the existing parser, AST, native emitter, and guard. Do not add another execution engine or a general optimizer framework.

Start with fixed-cost operations in straight-line regions. Split regions at branches, short-circuit paths, loop boundaries, calls, returns, potentially failing dynamic work, and externally visible mutations. Emit admission before entering each region. A control-flow path must not jump past admission or reuse its credit after a backedge.

Keep positive work checks on every repeatable loop path and function entry. Preserve call-depth checks, argument/result width, ownership validation, allocation admission, and fatal checks around protected/native calls. Variable-size concatenation, formatting, comparisons, copies, and host operations retain their own pre-operation accounting.

Separate constant work reservation from validation only where all callers have an explicit prepaid guarantee. Do not turn a generally reachable guard helper into an unmetered function. Keep source-location updates needed for ordinary errors; quota refusal can identify the new region boundary.

The initial eligible set must have an explicit control-flow and cost argument backed by tests. Leave other expression checks intact. If no region can satisfy the proof and timing gates, report that result before expanding scope; do not weaken a safety gate to finish the task.

Alternative rejected: remove expression checks globally. That can lose variable-cost charges, fatal barriers, and bounds on unreviewed control-flow paths.

### 7. Verify correctness and performance separately

Use existing fixtures rather than replace their assertions with a new minimal workload.

| Area | Required evidence |
| --- | --- |
| Logging | `tests/computer_contract.lua` and `tests/shell_contract.lua`: exact bytes, nil/false, empty entries, argument counts, zero results, prefixes, and prior-output survival. |
| Retention | Exact-fit and one-credit-short refusal before eviction; many-prefix eviction; lowered limits; unchanged saved order and metadata after cold reload. |
| Accounting | `tests/compiler_cache_contract.lua`, runtime tests, and native budget fixtures: equal warm/cold outcomes and paid prefixes, mixed work/allocation pressure, settings changes, and maintenance headroom. |
| Isolation | `tests/runtime_contract.lua`: private rebinding reset, protected namespaces, independent fatal state, fresh guest closures, and program/Console separation. |
| Authority | `tests/device_contract.lua` and `tests/monitor_optimization_contract.lua`: captured handles, wrong color/generation/scope, invalidating providers that throw, and native availability. |
| Compiler | Loop forms, recursion, short-circuit expressions, nested protected calls, stop, dynamic-size helpers, effect order, and original-source diagnostics. |
| Persistence | `tests/runtime_budget_engine.lua` and `tests/shell_cold.lua`: separate-process reload with pending work, retained logs, non-idempotent effect witnesses, and spent same-tick credits. |
| Visible Console | Existing native Console fixture: live output with Follow off/on, selection/copy between updates, visible eviction, and cold reopen. |

Pin the actual engine with `--version` and `--help`. Current `tools/smoke.py` requires Factorio 2.1.23; do not assume the older engine paths in project notes satisfy it. Use fresh external directories and the built ZIP. Follow each fixture's existing cold/production-context support rather than apply flags indiscriminately. Require exact completion markers, clean process exits, and no forced cleanup.

For performance, copy the frozen chest harness into a new evidence workspace. Keep its guest source, four real wired chests, item identities, quantities, 600-tick period, and individual output entries unchanged. Run matched baseline/candidate packages serially for three repetitions at 3,600 ticks and three at 18,000 ticks. Verify every output and deadline before comparing timing.

Measure whole scheduler reporting ticks and all-tick distributions separately. Include minimally instrumented native script-update timing. Collect deeper attribution and structural counts in separate diagnostic runs. Count physical owner checks, generic snapshots, reservations, environment construction, and moved log entries. Do not sum overlapping timer regions or interpret charge units as milliseconds.

Require repeatable reporting-cost improvement under matched settings before claiming an overhead reduction. Preserve medians, tails, individual runs, host contention, and failures. Do not infer a specific speedup from structural counts. If timing cannot distinguish a gain, report that limitation instead of raising budgets, merging output, or shortening the workload.

### 8. Keep typed API promotion separate from planning

The complete replacement drafts are `api/common.d.lua`, `api/computer.d.lua`, `api/globals.d.lua`, and `api/peripheral.d.lua` within this change. They change explanatory contracts, not signatures, annotations, return arity, or public identities. No public identity is removed. Generated limit declarations remain unchanged because the limits themselves do not change.

During implementation, promote the reviewed drafts into canonical `api/`. Regenerate both references with the existing tools. Update runtime documentation in the same task groups as the corresponding code. Use ASD-STE100 Issue 9 for new maintained prose. Do not hand-edit generated Reference pages or OpenWiki.

Behavioral spec synchronization is a later, separate workflow. Archiving the change does not promote typed declarations automatically.

## Risks / Trade-offs

- [Authority invalidation is incomplete] → Keep unknown providers conservative. Test revocation before effects and after throwing providers.
- [Shared code retains an invocation] → Use explicit private context and fresh guest-owned state. Test failed and interleaved executions.
- [Fewer reservations conceal unpaid work] → Prove bounded regions and retain dynamic operation checks. Sweep exact refusal boundaries.
- [Logging publishes before a later result refusal] → Prepay the empty result and all retention work before append.
- [Retention optimization misses a second quadratic charge] → Cover the shell dispatch overhead and all callers of the common writer.
- [Changed charges alter near-limit behavior] → Document the accepted compatibility change. Preserve the new version's cold/warm equivalence and completed effects.
- [Host timing noise looks like a speedup] → Compare serial matched runs and disclose contention. Keep diagnostic timing separate.
- [Compiler changes expand the diff] → Restrict the first eligible regions. Retain existing checks where the proof is incomplete.

## Migration Plan

1. Add regression coverage and preserve a matched baseline before production edits.
2. Apply direct output and linear retention together, including shell recovery overhead.
3. Apply admission specialization, stateless helper reuse, and reviewed local proof reuse with their own tests.
4. Apply compiler-region changes only after the earlier paths pass their safety and timing checks.
5. Promote typed declarations and regenerate references with each relevant implementation group.
6. Run packaged integration, cold reload, visible Console, and matched performance checks on the final candidate.

No persistent schema migration is expected. Preserve saved source, run IDs, queues, state, shell values, logs, and paid counters. Rebuild only process-local implementation artifacts from validated source. Do not trust saved generated text or reset a ledger to make new charges fit.

Keep the supported source/API/storage versions unless a demonstrated representation incompatibility requires separate review. Process-local cache keys must distinguish compiler policy where needed. Previously spent numeric credits remain spent; do not rescale or refund them during an update.

Rollback restores implementation code and canonical documentation together. It must not delete saved data or replay callbacks. Because the saved formats remain unchanged, rollback does not require a data rewrite. Any implementation that needs one exceeds this migration assumption and requires review before proceeding.
