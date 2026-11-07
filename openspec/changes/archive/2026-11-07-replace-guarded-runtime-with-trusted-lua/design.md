# Design

## Context

See `proposal.md` for the reason for this change and the accepted execution risks.

The current implementation already runs native Lua. `compiler.lua` emits instrumented operations, then `sandbox.lua` supplies the operation wrappers. Both saved dispatch and Console create that machinery for each invocation. The wrappers also provide useful host boundaries, symbolic Console bindings, output formatting, and error control. Removing the entire module without replacing these responsibilities would remove required behavior.

`admission.lua` currently combines compile work, callback work, and allocations in one shared total. `scheduler.lua` reserves an estimated maximum before selecting work. Its estimate includes the execution allowances that this change removes. `shell-values.lua` uses guard methods for both graph validation and temporary ownership. These call sites need separation, not no-op guard methods.

The implementation of `reduce-runtime-overhead` is the baseline, although that change is not archived. Keep its output publication, linear log eviction, and callback-local authority proofs. Remove its operation-metering optimizations with the execution model they optimize.

## Goals / Non-Goals

**Goals:**

- Use one native execution path for both source modes.
- Make the checked host boundary smaller than the execution machinery it replaces.
- Keep source validation independent from execution and persisted executable metadata.
- Preserve fresh callback bindings, compatible saved state, and exact service contracts.
- Delete obsolete mechanisms and their callers in the same implementation milestone.

**Non-Goals:**

- No watchdog, preemption, coroutine scheduler, interpreter, or hidden guarded fallback.
- No mutable-environment cache, durable closure, automatic replay, or broader Lua syntax.
- No direct Factorio access, new library members, new quota, or increased retained allowance.
- No change to native device availability, output ownership, queue policy, or Data persistence rules.

## Decisions

### 1. Retain validation; remove operation emission

Keep Phobos, `parse_admission.lua`, source tokenization, AST validation, declaration rules, reserved-name checks, and export discovery. Replace the instrumenting emitter with a validation walk and minimal native source assembly.

For saved programs, keep exports in a fresh private table behind the checked environment. Permit only validated export declarations to fill that table during function reconstruction. Close this construction phase before invoking a handler. Reject export reassignment during validation and through the environment after construction. Resolve exported names through the table, preserving forward references and mutual calls. Keep private helpers as ordinary lexical declarations in their original order. Do not add one lexical local per export: those extra locals reduce the source capacity available to existing private helpers. No export table or construction control becomes a guest value. Native assembly contains no operation probes, closure registration, staged assignment, or rewritten operators. Its size follows the accepted source and bounded export inventory; it needs no independent `generated_source_bytes` quota.

The maintainer approved this refinement after a pinned-engine compatibility probe. A 9,755-byte source with 160 private helpers and 64 exports compiles and runs on the preserved baseline. Predeclaring its exports adds enough locals to exceed the native 200-local limit. Loading the original declaration document without those added locals succeeds in base and Space Age. Keep this case as a compatibility regression; do not classify the added wrapper pressure as an accepted source limitation.

For Console, preserve expression-first validation and statement fallback. Evaluate the selected form in the staged command environment. Keep the existing distinction between genuine lexical locals and protected global names. Do not turn declaration-only programs into arbitrary chunks.

Keep an explicit source-line map for the small wrapper and the Console expression prefix. Preserve comments, string bytes, and accepted lexical prefixes without moving their logical source positions. Native loading checks syntax without invoking player functions. Runtime diagnostics use host-only native stack information when available, mapped to the original source. A missing native column is column 1.

The private bounded cache stores source-derived validation results, wrapper text, and host-charge evidence. A returned plan is not executable authority. Revalidate source or replay a private exact-source proof before loading; ignore caller-provided executable text. Fresh functions and environments are reconstructed for each callback. Cache hits and misses retain equal host admission for equal inputs and credits.

Alternative rejected: retaining the current emitter with disabled guards. That leaves a second language implementation, generated temporaries, and obsolete failure paths in the hot path.

### 2. Replace the execution guard with one checked environment module

Add `scripts/runtime/environment.lua` as the replacement for `scripts/runtime/sandbox.lua`. This proposed module owns the restricted environment, boundary helpers, private fatal controls, diagnostic conversion, and authentic binding registry. Delete `sandbox.lua` after its callers move; do not keep a forwarding module or backend selector.

Ordinary arithmetic, comparison, indexing, constructors, assignment, calls, loops, recursion, and result adjustment execute natively. No registry tracks every temporary table, closure, string, or tuple. No call-frame stack exists solely to meter execution.

Keep immutable proxies for libraries and API facades. Their backing tables remain private. Raw access, iteration, and table helpers reject protected or foreign tables. For ordinary plain values, identity and native key rules apply without temporary capacity checks. Every host result still follows its declared defensive-copy or detached-native-transfer contract.

Keep small private maps only where they represent real authority or metadata: protected objects, stable safe-format labels, facade/method descriptors, and invocation-local proofs. Share stateless helper implementations and immutable descriptions. Never share a mutable execution owner, fatal state, selected wire, pending command, or scratch root.

Native math helpers do not synthesize finite-value errors. API and Data validators continue to reject values outside their own numeric domains. Native table helpers replace staged sorting and dense-sequence emulation. Preserve the existing safe formatting, literal-only `string.find`, protected-object exclusions, and documented protected-error handling. The change-scoped declarations state the exact exceptions and return counts.

Alternative rejected: directly exposing the host environment or complete standard libraries. Trust concerns execution resources, not authority over the mod or Factorio.

### 3. Close the native string-index route without instrumenting indexing

Restricting the global `string` table alone is insufficient. Native strings also obtain members through their shared metatable. Computed string indexing could otherwise expose excluded members, even with colon syntax disabled.

During guest execution, select the approved immutable string-member table as the mod-local string metatable's `__index`. Restore the preceding index on every exit. Checked host entry temporarily restores the host index; return or failure restores the guest index before guest code resumes. Pure native helpers that call guest code, including sort comparators and protected message handlers, keep the guest index active. A host callback bridge must restore guest scope before invoking guest code.

Use one exception-safe scope mechanism. It must cover nested host entries, error conversion, stop, fatal admission, ordinary failure, and command publication. Do not replace host string methods permanently or mutate the metatable in `on_load`. No metatable reference becomes a guest value.

An isolated Factorio 2.1.23 runtime probe verified that string index replacement, checked host re-entry, and restoration after an error are possible. It also observed hidden members such as `dump`, `match`, `gsub`, `pack`, and `unpack`. This establishes mechanism feasibility, not integrated security or multiplayer acceptance. The implementation tests must exercise all exit and callback routes in both content modes on the pinned engine.

Alternative rejected: emitting a wrapper for every indexed expression. That would retain operation instrumentation and its substantial compiler/runtime machinery.

### 4. Preserve fatal controls without metering ordinary calls

Keep a private invocation status for stop and fatal host-work refusal. Checked API entry, protected-call exit, message-handler entry, and host publication inspect it. A guest cannot receive or forge its private control value.

`pcall` and `xpcall` remain thin boundary adapters around native protected execution. They preserve their documented nil arity, guest-error identity, safe host-error copies, and protected-handle differences. Check fatal state before invoking a guest error handler and before returning from a protected call. Nested protection cannot hide fatal state or permit later effects.

Native stack, arithmetic, and helper failures are ordinary failures, not synthetic execution-quota faults. Native error-handler re-entry has no mod depth ceiling. Earlier successful effects remain real. Console graph publication remains atomic even when temporary tables have changed before a failure.

Stop works only after code calls the host or returns control. Neither these adapters nor scheduler fairness interrupt a pure infinite loop.

Alternative rejected: exposing native protected calls unchanged. They could catch the private stop/admission signal and let execution continue incorrectly.

### 5. Retain host admission and remove execution accounting

Keep `compile_work`, `host_work_per_tick`, the maintenance reservation, source capacities, and device-specific work limits at their current values. Host work includes validation, reconstruction, API processing, output construction, graph encoding, and maintenance. Ordinary Lua operations do not spend it.

Remove per-computer callback work and allocation ceilings. Remove allocation reservations rather than converting them into invented host-work charges. Preserve real host traversal/copy charges and required pre-effect admission. The shared aggregate constrains API work; source work also retains its existing per-computer compile allowance. The existing active-admission capacity still bounds the per-tick identity inventory.

Reduce `admission.bind` to the live host-work path. Remove its allocation closure and allocation kind. Rename `guest_ceiling` to describe host work. Retain charge replay where source validation or callback-local physical proofs use it, without a retired callback ceiling. Reject stale tick/identity bindings exactly as before.

Version the ledger for its new shape. For a known version-1 ledger, preserve `tick`, `total`, compile credits, and the maintenance alias. Remove obsolete execution/allocation fields only during synchronized migration. Preserve the old aggregate total conservatively until the normal tick transition; do not refund old charges during upgrade.

Replace both scheduler admission estimates that sum `compile_work`, `callback_work`, and `callback_allocations`. Select work through the existing ready rotation and program/Console alternation. Admit actual source/host work through the shared ledger. Do not reserve a fictitious full invocation allowance. Once execution starts, a refusal completes the existing fault path, not a command retry.

Before execution, treat validation, fresh environment construction, event copying, and Console graph reconstruction as preparation. Keep the pending item until this work is admitted. If earlier work leaves too few credits, retain the item and its order for a later tick. Keep all accepted preparation charges spent. Do not echo a deferred command or change its committed graph. Recheck current authority on each attempt; canceled authority still consumes the item visibly.

Track the preparation's initial aggregate and compile totals only in its ephemeral host context. At a refused charge, compare the paid preparation prefix plus that charge with the full current source and host allowances. Defer only if both can admit that prefix without earlier work. Otherwise, report the existing failure instead of deferring an impossible preparation. Apply this rule to ordinary, bound, and replayed charges, preserving identical warm/cold refusal prefixes. Do not reset a ledger or introduce a new allowance.

Consume the item immediately before invoking its handler or Console chunk. Source declarations may be reconstructed before consumption; they cannot execute a callback or API effect. After consumption, host refusal remains fatal and the item is never retried. Preserve once-per-tick dispatch, lane alternation, event metadata, and stale-command cancellation. This is preparation deferral, not suspension or replay of running Lua.

Alternative rejected: keeping the old settings as ignored aliases. They would advertise protections that no longer exist and preserve unnecessary code paths.

### 6. Move every device route onto the checked boundary

Adapt `computer.services` and `peripheral.services` to the environment's actual host operations, not a guard-shaped compatibility object. Preserve exact arity, domain checks, Data validation, owner checks, result copying, and declared zero/multiple returns.

Reuse `principal.proof` and the existing invocation-local topology proof. Keep identity, generation, force, surface, selected wire, path, and optional-method checks on wrapped calls, captured methods, and `peripheral.call`. Invalidate proofs before a potentially changing provider call, including one that throws. Native power and method availability remain live checks.

Remove `prepare_boolean_result`, `prepare_empty_result`, and `prepare_string_result` where they exist solely for guest tuple/allocation admission. Preserve separate host pre-effect work and retained publication checks. Detached circuit results keep their existing isolated complete-result transfer path; remove temporary-width exemption machinery that has no remaining temporary limit to exempt.

Remove `tuple_entries` checks from `peripheral.find` and fixed provider registration. Keep the closed provider inventory, valid names/functions, required methods, topology capacities, and full-discovery admission. Do not replace multiple returns with an array or silently truncate results.

Keep the optimized direct local-output writer and linear oldest-prefix eviction. Formatting and the complete entry are admitted before append or eviction. Remove guest-result prepayment, not Console byte/entry limits, attribution, safe descriptions, or cancellation checks.

Alternative rejected: enforcing authority only in the environment's generic call wrapper. Direct native calls must remain safe without an execution guard.

### 7. Keep Console graph ownership distinct from temporary ownership

Retain the graph format and its byte, node, binding, scalar-key, string, and per-table constraints. `shell-values.lua` uses host work and explicit graph validation, not temporary allocation registration. Create ordinary reconstructed tables directly after the retained graph is validated/admitted.

Keep authentic descriptor maps for facades and captured methods. Restore facade nodes before dependent method nodes. Preserve method aliases before their first use and keep distinct wrapped facade identities distinct. A descriptor-shaped guest table never becomes authority. Executable closures, ordinary built-in functions, namespaces, and reference keys remain unsupported retained values.

Publish the new graph only after successful execution, result formatting, complete encoding, and a final owner/fatal-state check. A failed command retains the prior graph and earlier external effects. Pending commands retain their accepted sequence and are never replayed after execution starts.

Alternative rejected: treating every native table as safe persistent Data. Temporary native values and retained application data are different contracts.

### 8. Explicit cleanup map

These components are live in the baseline. They become obsolete only after their replacement callers are connected. The removal decision is certain for the accepted policy; this is not a claim that they are dead today.

| Area | Delete or replace | Keep and verify |
| --- | --- | --- |
| `scripts/runtime/compiler.lua` | Instrumented expression/statement emission; `__tc` calls; prepaid regions; generated temporary names; staged-assignment emission; generated-text ceiling | AST validation, source admission, exports, source proof, cache determinism, native load, source-line mapping |
| `scripts/runtime/sandbox.lua` | Entire module after moving required responsibilities | One replacement `environment.lua`; no compatibility shim |
| Execution internals | `step`, `region`, `enter`, `loop`, temporary binding/tuple checks, call-depth stack, operand wrappers, constructor ownership, allocation counters, staged assignment/sort | Private fatal status, safe diagnostics, protected namespaces, native helpers, boundary copying |
| Native circuit exceptions | Temporary array/string growth flags and special operation metering | Complete detached results, queue isolation, native metadata shape, caller-request validation |
| `scripts/runtime/admission.lua` | Allocation accounting, callback ceilings, obsolete bound closures | Shared host totals, compile work, maintenance reservation, stale-context checks, useful ordered proof replay |
| `scripts/scheduler.lua` | Full-invocation estimates using retired allowances | Ready selection, due timers, one item per computer per tick, alternating lanes, maintenance bounds |
| `computer.lua`, `shell.lua`, services | Guard-only constructors/calls and guest-result reservations | Principal checks, pre-effect host admission, output, transactional persistence, exact return contracts |
| `shell-values.lua` | Calls that register temporary ownership or allocate through a guard | Validated graph format, authentic symbolic binding reconstruction, host work, atomic publication |
| `limits.lua`, `budget-settings.lua`, `settings.lua`, locale | Five retired limit fields; two retired settings and their descriptions | Other defaults and effective settings, with boundary-only descriptions for string/table limits |
| `tools/player_docs.py`, API generators and tests | Sandbox-source discovery assumptions; descriptions of retired limits | Export completeness from the replacement module and generated-reference checks |
| Runtime/compiler/cache/device/shell fixtures | Assertions that require operation probes, temporary quotas, staged sort, or callback pre-reservation | Replacement native-behavior tests and all surviving boundary/authority/persistence assertions |
| Maintained docs and generated Reference | Claims of preemption or hard guest temporary/execution containment | Trusted-code warnings, persistence rules, service limits, native examples and help |

Also search `tests/speaker_admission.lua`, `tests/network_engine.lua`, `tests/monitor_optimization_contract.lua`, and scheduling/client fixtures for guard doubles. Replace necessary boundary doubles; remove no-op methods that only imitate deleted execution machinery. Update build/test selectors and imports if a fixture moves. Preserve unrelated assertions and historical evidence.

Do not delete `parse_admission.lua`, `data.lua`, `principal.lua`, or `shell-values.lua`. Their remaining callers enforce surviving contracts. Do not hand-edit generated OpenWiki or rewrite old change artifacts.

### 9. Typed API promotion and compatibility

The twelve `api/**/*.d.lua` drafts are complete affected-file replacements. `proposal.md` lists the five removed `TC.Limits` identities. `TC.StringInput` documents native string coercion without changing device argument types. The generated limits draft is a target, not a claim that the current generator already emits it.

Native helper differences are intentional. For example, the pinned engine returns zero values for empty/past-end `table.remove`, requires a start argument for `string.sub`, and rejects omitted `type` input. Native math can produce nonfinite temporary results. Keep safe formatting and existing protected-object/error exceptions explicit rather than implying unrestricted native libraries.

During apply, promote accepted authored declarations into canonical `api/`. Update the actual constants and limit descriptions, then regenerate generated declarations and both references with existing tooling. Run candidate API checks again against the final implementation. Behavioral spec synchronization is a separate archive operation; typed drafts are not copied by spec sync.

### 10. Verification and performance evidence

Use finite tests above former temporary limits, not infinite loops or intentional memory exhaustion. Compare permitted helper behavior with the actual pinned engine, including sparse sequences, native error cases, nil arity, and native sorting after comparator failure.

Security acceptance covers protected namespaces, dynamic string indexing, guest callback scope, fatal-control escape, authentic bindings, every device call route, and native-circuit isolation. Persistence acceptance covers the real old archive, configuration-change upgrade, cold reload, and connected late joining. Mocked graphs and a fresh save alone are insufficient.

The current manifest targets Factorio 2.1 and the harness pins 2.1.23. Run both base and Space Age with that engine. Use older engines only to produce required historical upgrade inputs. Keep the exact version and bundled-mod set in each receipt. Preserve deadlines, finite workloads, and remaining production allowances. Use headless contracts and generated-documentation checks to verify Console semantics and trusted-runtime warnings. Full-client visual validation is not required for this runtime-only change. Connected late-join correctness remains a separate required gate; it does not require visual acceptance.

Compare the final uninstrumented candidate with the optimized pre-change archive at both 30-tick and 600-tick polling. Keep the original guest source, circuit scene, outputs, warmup duration, windows, and settings. Run matched repetitions serially in both orders. Report scheduler/reporting/native update statistics and tails separately. Keep attribution instrumentation in a diagnostic archive. This plan sets no invented percentage target; report regressions and unresolved trade-offs before implementation handoff.

Structural acceptance requires no execution-only guard calls, no guarded fallback, no stale helper-export source, and no active retired settings/limits. A smaller file or a passing glob check alone does not prove cleanup.

## Risks / Trade-offs

- Runaway code can block the simulation or exhaust memory → State this risk in both execution modes. Use finite acceptance tests and isolated saves.
- Native errors and temporary mutation differ from old wrappers → Preserve API/retention atomicity and publish exact compatibility notes.
- A string-index scope leak can expose host helpers or break host code → Test all nesting, callback, and exit routes against native engines.
- Removing ownership trackers can expose a missed host reference → Audit every transfer boundary and use adversarial isolation tests.
- Old compiler headers currently fault before reconstruction → Migrate before scheduler validation, timer advancement, or queue consumption.
- First synchronized validation can refuse host work → Retain the pending upgrade and source without executing or replaying it. Retry only unstarted validation under existing admission.
- Fresh reconstruction still costs time → Keep it for compatibility and measure the replacement. Do not hide an environment-cache redesign in this change.
- Two unarchived changes overlap → Preserve the earlier change and synchronize its deltas before this change when archival is separately authorized.

## Migration Plan

1. Preserve the optimized baseline archive and its source/evidence identity before implementation.
2. Set the compiler representation version from 2 to 3; retain public API/storage versions where their formats do not change.
3. Introduce a versioned host-only ledger conversion for known version-1 data. Preserve same-tick totals and maintenance aliases.
4. Register migration through existing synchronized initialization/configuration-change paths before normal scheduler header checks.
5. Validate each known active source against the new frontend before marking its compiler header current. Do not invoke its startup function.
6. Preserve active versus later saved source, revisions, run IDs, accepted queues, deadlines, shell graphs, and ownership records.
7. Keep unvalidated work inert when admission is unavailable. Preserve unknown or malformed data with an actionable diagnostic; never repair it by resetting credits.
8. Remove obsolete generated metadata/counters only after their supported replacement is established. Never run old generated code as a fallback.
9. Verify old-archive upgrade, separate-process cold reload, and connected late joining without state changes during `on_load`.

Rollback uses the preserved pre-upgrade save and baseline mod archive. Do not promise that an old runtime can load a save already written by the new compiler/ledger versions. Retain player source and data rather than attempting a lossy automatic downgrade.
