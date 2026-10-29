# Design

## Context

See `proposal.md` for motivation and `specs/program-source/{spec,lua-api}.md` for the behavioral contract. The user confirmed that manual invocation means ordinary calls inside the same saved program, not calls from Console.

Observed roots of the current restriction:

- The pinned parser already represents ordinary declarations as `funcstat` and local helpers as `localfunc` (`vendor/phobos/parser.lua:1196-1220,1292-1309`). Bare unresolved names are marked global-style `index` nodes, whereas lexical locals/upvalues have their own nodes.
- `compiler.lua:84-214` already instruments function bodies, calls, local closures, assignment and loops. Its global-read allowlist and global-write rejection must not become generally permissive.
- `compiler.run` (`compiler.lua:321-347`) recompiles/revalidates exact source, reserves reconstruction, creates a new sandbox/factory, and calls the selected table entry. There is no persisted executable environment.
- `sandbox.lua:89-132` validates callable values, registers guest closures, and admits argument/return work and call depth. All exported function values require callable validation.
- `computer.lua:67-93` activates a plain source/version/handler-name record and queues optional `start`. Timers/subscriptions validate names against that record. `scripts/lifecycle-data.lua:20-31` accepts a closed active-record shape, so an unnecessary new persisted format discriminator would also affect transport.
- `scripts/ui/editor-model.lua:81-99` already feeds both draft validation and saved activation through the compiler. `scripts/ui/help.lua:3-14,45-54` contains the inserted starter and language guidance.
- `openspec list --specs` returns no canonical capabilities. The source contract is currently in the in-flight `add-native-circuit-computers/api/native-language.md:5-9`; the new `program-source` capability extends that restriction without copying or weakening the broader runtime requirements.

### Feasibility evidence

An isolated planning fixture was injected into a copy of the current built archive. All 436 original ZIP entries were compared byte-for-byte and left unchanged. Factorio 2.0.77, build 84539, passed 31 contract groups in both base and Space Age: the existing 27 runtime groups plus four probe groups covering parser shape/current rejection, guarded aliases/protected calls/nil tuples, fresh function construction without executing `start`, and fatal mutual recursion.

The probe explicitly lowered a small example into native local functions using the existing shell emitter and called it through the existing sandbox. It did not implement declaration-form saved-program compilation, expose program functions to Console, run the new editor flow, or verify new cold/multiplayer behavior. Initial direct-parser probing failed because the fixture omitted `parse_admission.begin/finish`; the corrected fixture passed in fresh directories. The failed attempt is retained separately.

Evidence directory: `/home/siredvin/artifacts/tweaked-computers/function-program-proposal-2026-10-19/`.

- Baseline mod SHA-256: `7ad7868c90ad07465d8abed41ba8ce25440dc9ed6c14d21d8201ed696651f119`.
- Probe-only mod SHA-256: `1574d264f725a4fafc8f5d5f0bd29716d741b2a25520299590616f2d0890fab4`.
- `summary.json`, mode-specific logs, fixture source and `provenance.json` describe precisely what ran. `failed/` contains the original fixture failure.

This establishes that the necessary native/guarded building blocks work, not that the proposed feature is already complete.

## Goals / Non-Goals

Goals:

- Add one bounded source-form branch to the existing compiler, returning the same plan and handler inventory expected by all downstream consumers.
- Reuse parser lexical resolution and native Lua closures; retain source locations and identical warm/cold proof admission.
- Keep authoring straightforward without adding public invocation APIs, mutable globals or hidden durable environments.

Non-goals:

- A general module system, multi-file imports, top-level initializers, persistent captured variables or arbitrary native source execution.
- Console integration, a new execution backend, scheduler reentrancy, callback suspension, expanded budgets or full-Lua compatibility.
- Rewriting every existing example or changing unrelated lifecycle, peripheral or GUI presentation behavior.

## Decisions

### 1. Distinguish source forms structurally after the existing parse

Keep program mode distinct from existing shell mode. Examine the top-level statement list under compile admission before emitting a program. The legacy branch keeps its exact accepted grammar. The declaration branch permits only empty statements, simple exported `funcstat` nodes and private `localfunc` nodes, with at least one export. Reject all other or mixed shapes before factory execution.

Perform a bounded first pass to inventory public/private names, detect duplicate/reserved names and enforce the exported handler limit. Then emit bodies in source order. Every new scan/name check/emitted byte remains within the existing parser/emitter accounting, and metadata cached by exact source remains plain validated data.

Alternatives rejected: textual/regex wrapping would mishandle strings, comments, nesting and lexical scope; executing arbitrary source to discover functions would permit module effects during reconstruction. A public source-mode setting or persisted discriminator is unnecessary because source already determines its form.

### 2. Resolve public function names through one private per-dispatch binding table

Create a compiler-private function table before constructing bodies. Populate each exported name with its instrumented native closure, and return that same table as the scheduler's handler table after all declarations have been constructed. In the new form only, a parsed global-style read that matches a declared export becomes a checked read from that table. Leave parser-resolved lexical references untouched, so parameters/locals shadow exports normally. Non-export reads still pass the existing approved-global checks; all guest global writes still fail.

Use one private table rather than a separate captured native local for every export, avoiding extra per-closure native upvalue pressure at the supported exported inventory. The table is an implementation detail and must not be exposed as `_G`, `_ENV` or a guest namespace. It can reuse `G.new`/`G.get` ownership and lookup admission. Statically emitted population is bounded by the inventoried exports and must be completely prepaid with the existing guard accounting before mutation; no user expression computes keys or values other than constructing guarded closures. Prefer reuse over a new registry API, and avoid adding a sandbox helper unless existing guards cannot express the required admission cleanly.

Every exported function must pass through `G.closure`, not merely appear as an unregistered raw native handler. This preserves `type`, `tostring`, returns, aliases, temporary tables and `pcall` through the existing callable-value validation. Function bodies and all calls continue through the existing `func` emitter and `G.call`; do not route a direct call through `compiler.run` or enqueue it.

Top-level local helpers use the existing `localfunc` emitter and parser lexical binding. They are constructed in source order, absent from the export table, and visible only where normal lexical scope permits. Public names resolve for the whole declaration document, including from private helpers, because all bodies run only after table population. Distinct top-level names and reserved-name rejection avoid ambiguous rebinding; body locals retain existing rules.

Alternatives rejected: mutable sandbox globals weaken the current trust boundary; rewriting references by text breaks shadowing; wrapping every helper in a new callback refreshes authority/budgets and loses ordinary arguments/results. Hoisting private helpers would silently depart from their lexical semantics.

### 3. Preserve scheduler, source snapshots and versions

The plan continues to carry API version, compiler version, exact original source, generated text, handler-name map and node count. Activation keeps `api_version=1`, `compiler_version=2`, `storage_version=1` and the current closed retained record. Declaration export names simply fill the existing map. No new version is required because supported old source/records still reconstruct and no executable generated text is trusted from persistence.

Do not change timer/event APIs: they keep string names and their existing envelopes. Ordinary calls are within one already-dispatched callback and use native argument aliasing/return adjustment; queued callbacks retain copied events and fresh environments. A direct `start()` does not change lifecycle metadata, though its explicit user-written effects execute normally.

The exact-source cache remains mode-separated and stores no AST, functions or mutable caller-owned plans. New-form compile/reconstruction tests must cover accepted prefixes under refusal, eviction and caller mutation, not only successful warm runs. On load, no source or factory runs; subsequent synchronized dispatch reconstructs only the saved active source, even if a different draft/saved revision exists.

Alternative rejected: bumping the compiler version solely for additive syntax would fault otherwise compatible active programs under the current exact version check. If implementation discovers an actual retained-contract incompatibility, stop and revise the compatibility design rather than silently bumping versions or resetting running computers. Downgrades after authoring new syntax are not promised.

### 4. Additive authoring rollout, not mass conversion

Change `scripts/ui/help.lua`'s inserted starter and language section, and add a shipped minimal example demonstrating `sample()` followed by `computer.every(..., "sample")`. Update the primary language/computer/example documentation plus source-language claims in current runtime and Console docs.

The editor model should need no source-format branch because it already invokes the compiler. Extend its contracts to exercise insertion and same-tick Validate/Save/Run using the exact maintained example under unchanged limits. A text-only starter/reference change does not require redesigning or screenshot-testing the editor layout; do not describe mocked editor actions as native input delivery.

### 5. Verify the actual saved-program frontend, not just the planning probe

Extend `tests/runtime_contract.lua` for accepted/rejected grammar, export visibility, private helpers, shadowing, ordinary values/tuples, original-source diagnostics and fatal direct/mutual recursion. Include maximum exported inventory, adversarial names, nested redefinitions, mixed formats and failed replacement. Reuse the existing shell contracts to guard mode separation.

Extend `tests/compiler_cache_contract.lua` for both source forms, including partial compilation refusal and mutable plan isolation. Extend `tests/computer_contract.lua` and `tests/computer_cold.lua` with declaration-form activation, direct-plus-timer effects and separate-process retention alongside legacy source. Keep snapshot comparisons, original active source versus unapplied saved text, same-tick credits, plain persisted graph, once-only startup/one-shots, and normal `/quit` verification. Add/extend existing editor contracts for exact starter source and error navigation. Add the affected cold fixture to CI if not already invoked; do not create a parallel harness.

Run packaged tests through `tools/smoke.py` in both base and Space Age for changed contracts and cold scenarios, plus focused cache/shell/editor regressions and existing package/docs checks. Explicitly record the archive hash, engine modes, fixture names and cold phase results. Actual multiplayer late joining is not established by these tests; this additive source change must retain the current deterministic/data-only architecture without claiming a new multiplayer proof.

## Risks / Trade-offs

- [Public function declarations resemble global writes] → Treat them as a closed top-level declaration form, never as permission to mutate the environment; test nested redefinition and protected names separately.
- [Function values fail scalar/callable checks or escape guards] → Register every constructed exported closure, share the same table value for dispatch and direct use, and test alias/return/pcall paths.
- [Forward-reference rewriting breaks local scope] → Only redirect parser-marked global reads that match the public inventory; preserve local/upvalue nodes and private helper declaration order.
- [Native limits or reconstruction overhead shrink the usable envelope] → Use a shared private table, test the supported maximum exports and realistic starter on unchanged limits, and reject unsupported native/source envelopes with source-located diagnostics. No performance improvement is claimed.
- [Cache or retained metadata disagrees between cold and warm peers] → Keep exact source authoritative and prove equal charge traces/refusal prefixes; serialize only the unchanged plain inventory/source shape.
- [Too broad a convenience feature becomes a module system] → Keep top-level values/effects and cross-document/Console calls explicitly out of scope.

## Migration Plan

1. Implement and verify the additive compiler path with legacy source and retained records unchanged.
2. Publish the updated starter/reference and representative example only after they execute through the actual saved-program compiler and editor/runtime flow.
3. No source rewriting or data migration runs on load or configuration change. Players adopt the syntax by editing and explicitly applying a new revision.
4. Rollback before adoption is an ordinary code rollback. After new-form source is saved, preserve a backup or convert/reapply it under a compatible runtime before downgrading; an older compiler cannot execute syntax it never supported. Never delete source/state to conceal incompatibility.
