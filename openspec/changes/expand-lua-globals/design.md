# Design

## Context

See [proposal.md](proposal.md) for motivation and agreed scope. Design is warranted because the changes touch compiler admission, the sandbox trust boundary, logging and retained Console names.

Observed implementation:

- `scripts/runtime/compiler.lua:20-21` has the saved-program global allowlist. `:48-57` separates forbidden host names, reserved declarations and Console write protection. `:247` rejects reserved public/private top-level declaration names; legacy descriptor keys at `:303-308` are not global bindings.
- `scripts/runtime/sandbox.lua` owns native execution guards: `G.call` handles depth, tuples, result validation and poison checking; `G.assignment_check` validates complete indexed writes before publication; `G.length` validates owned tables/strings. The owned/protected/callable registries are private ephemeral weak-key tables.
- The same sandbox initializes both guest modes. `env.print` currently exists only inside the shell branch at `:505-518`; it already formats safe tab-separated tuples and is used by shell expression-result display.
- `scripts/runtime/computer.lua:18-26` appends bounded log entries after charging retention work. Its registered `computer.log` service supplies current-record authority and the current guard. `scripts/runtime/shell.lua:33-36,83-87` supplies command prefixes and checks their full byte size.
- `scripts/runtime/shell-values.lua` encodes/decodes a bounded graph with root bindings, aliases, cycles and symbolic peripheral bindings. New helpers must not become new persistable function kinds. Root-name validation currently checks identifier shape, not collisions with newly introduced built-ins.
- Existing specs/docs explicitly forbid saved `print` and raw access, while tests include `print(1)` in the rejected-source list. Those are deliberate contracts to update, not evidence that the existing code accidentally omitted an allowlist entry.
- The pinned engine's bundled and matching official libraries page identifies modified Lua 5.2.1 behavior. Host `print` goes to stdout, so exporting it directly would violate the agreed Console destination. The Lua manual/source establish ordinary base-function behavior; neither source proves guard safety.

## Goals / Non-Goals

Goals:

- Fit each addition into existing native guarded execution, with one implementation shared by saved callbacks and Console commands.
- Preserve all existing bounded mutation, protected-object, output attribution, error, retention and cold-load boundaries.
- Make compatibility differences explicit and executable as contract tests, including rare old-name collisions.

Non-goals:

- No interpreter, continuations, general compatibility framework, new dependency, library loader or new persisted executable representation.
- No conversion of transient identity operations into Data-copying service calls.
- No broad cleanup of compiler/runtime code, changes to devices, UI redesign, speculative standard-library expansion or production-budget increases.

## Decisions

### 1. Extend the existing allowlist and environment, not the execution model

Add the named globals to the existing compiler/global-environment definitions. Remove their treatment as excluded raw facilities where applicable, while preserving top-level name reservations and Console write protection. Keep host/global escape bans closed. Make `_VERSION` a fixed language-family string and `unpack` the very same wrapper function as `table.unpack`; initialize stable callable descriptions once so alias registration order cannot make function descriptions differ between peers.

Tests must compare availability, reservation and behavior in both saved formats and Console. There is no reason to add a plugin registry or generate another API table for this small surface; a focused parity test is sufficient to catch compiler/environment drift.

Alternative rejected: expose Factorio's entire `_G` or native standard libraries. Presence in the host does not imply guest ownership, paid work or appropriate authority. Metatables would affect every indexed/operator/call path, not just add two functions; patterns, binary packing and randomness also need their own resource/state contracts. They remain separate work.

### 2. Reuse the print formatter with a mode-appropriate existing sink

Move the current `env.print` definition outside the shell-only branch. Share formatting, safe stringification and tuple/byte/allocation admission. In saved mode send the completed string through the already guarded `computer.log` service; in shell mode retain the existing `shell.output` sink so command attribution and its prefix-inclusive size check stay unchanged. Keep shell expression display calling the same formatter. Do not call host `print`, `game.print` or `log`.

Check output length during accumulation and before joining, then pay output allocation and the sink's log retention cost before publication. Existing `M.log` already precharges before evicting entries. A formatter refusal must leave logs unchanged except for independent normal fault/command diagnostics; a later guest error does not undo earlier successful output. Keep zero-argument prints distinct from zero-result expressions.

Alternative rejected: implement `print` as a public alias to `computer.log`. Its one-string signature, argument conversions and nil/tuple semantics differ. Also reject recursive pretty-printing and automatic monitor selection: neither is requested.

### 3. Raw helpers reuse ownership and write/length admission

Define these functions inside the sandbox, where private ownership checks already exist. They are not host services: passing table arguments through `G.service` would snapshot values, destroy raw identity and reject valid transient cycles.

- `rawget`: require `plain(t)`; validate/meter the key using existing helpers, with explicit nil/NaN read handling rather than blindly calling `G.get` (its key validation rejects those). Return the native stored value, preserving one-nil return arity.
- `rawset`: validate `plain(t)`, key and `G.scalar(value)`; reuse the single-target form of existing indexed-assignment admission, including table inventory, capacity, tuple/target work and allocation, before one native write. Return `t`. Do not implement a second divergent growth policy or expose a general unguarded setter.
- `rawlen`: reuse `G.length`'s validated/metered semantics on plain tables and strings. Metatables remain impossible, so this agrees with native raw length over the accepted domain.
- `rawequal`: validate both guest operands, admit bounded string comparison work before the native comparison, and do not copy references. Approved facade/function identity comparison is safe; raw reading/mutation of facade contents is not.

Transient guest tables may already contain function/reference keys or cycles; the unchanged Data and shell serializers remain their separate persistence boundaries. Shell name-collision checking applies only to root global keys, not nested fields.

Alternative rejected: exporting bare host `rawset`/`rawget`. It would bypass ownership, metering and growth checks and make protected empty proxies appear like ordinary mutable tables.

### 4. xpcall uses native protection behind a guarded message bridge

Use native `xpcall` with host-owned closures that invoke the supplied function and message handler through `G.call`, preserving current guard/depth and nil-containing tuple handling. Reuse the error sanitization rule already present in guest `pcall`: guest-owned references stay references; host-origin ordinary error tables become approved defensive snapshots. Keep the bridge and result tuple private.

The bridge checks poison before invoking guest message code. If the protected function or message handler triggered fatal control, it must stop guest error handling without allowing native recursive error handling to repeatedly call guest code. After native protection returns, perform `G.check` before examining/publishing any guest result; private control values never escape. Bound native message-handler re-entry with the existing callback-depth/work limits, including failures during sanitization or inside the handler itself. Do not let `G.call` cleanup decrementing its depth counter accidentally leave host message-handler recursion unbounded.

Success preserves the exact native result tuple plus its status. Ordinary failure keeps only the first handler result, even when nil or absent. Validate and charge the final tuple including the status. A maximum-sized unprefixed result is not permission for a status-prefixed overflow.

The first implementation gate compares benign argument/result/error-handler behavior against the exact Factorio engine, then separately exercises adversarial poison/re-entry behavior. Host `debug.traceback` is neither required nor exposed. Exact native error-in-handler wording is not promised; native ordinary failure behavior within unchanged guard bounds is.

Alternative rejected: bare native `xpcall`, which could expose the private fatal sentinel to a guest handler. Also reject an unprotected handler call after a guest `pcall`: it does not preserve protected message-handler failure behavior. Do not introduce a bespoke resumable exception runtime.

### 5. Handle newly reserved names without a save rewrite

Keep API version 1, compiler representation 2 and storage version 1 if generated `__tc` interfaces and stored representations remain unchanged. Adding entries to the existing environment does not justify faulting every running computer through a blanket ABI bump. Exact source is reconstructed using the current trusted compiler; do not persist or reuse old executable objects.

Declaration-form collisions already flow through reserved-name rejection. Validate/Apply failure preserves the current run. A colliding old active declaration faults only when synchronized reconstruction is attempted, using existing cleanup and retaining source/state; no `on_load` mutation or automatic rename. Preserve legacy descriptor handler-key behavior and body-local/parameter shadowing.

For Console, detect a newly reserved root key during admitted decode, before guest execution. Use a small host-only check against the actual built-in environment or shared existing inventory, not another public guest API. Return `E_UNSUPPORTED` naming the conflicting key and explaining explicit Reset Shell. Preserve the old graph; do not silently prioritize the built-in over stored data. Bound the check within the already bounded decode traversal. Nested keys remain ordinary data, and saved-program execution is unaffected.

Alternative rejected: automatic reset/migration or retaining old bindings as silent shadows. The first destroys data without consent; the second makes the API depend on session history and can hide the new functions.

### 6. Update public contracts and executable examples together

At implementation, reconcile the explicit exclusions/inventories in `openspec/api/native-language.md`, existing runtime/Console/source companions, player language/Console/computer pages and in-game help. Merge the new runtime companion material into the existing companion; it is an extension, not a replacement that deletes computer methods/timers/events.

Change `examples/function-program.lua` and the matching `scripts/ui/help.lua` template together to teach multi-argument `print`; `tools/player_docs.py` checks their exact equality. Regenerate only the existing maintained example/document outputs as needed. `tools/planning_examples.py` extracts main-spec Lua blocks into `examples/planning-programs.lua`, and `tests/runtime_contract.lua` currently asserts an exact example count. Avoid silently changing that inventory or treating newly generated examples as already executed.

No generated OpenWiki page is hand-edited. The separate inspector and radar proposals are outside this change.

## Risks / Trade-offs

- [Raw access becomes an unmetered alternate mutation path] → Reuse existing admission, refuse protected/foreign tables, test exact-capacity replacement/deletion, oversized keys and one-unit-short mutation refusal with alias readback.
- [Fatal errors reach xpcall's handler or native error recursion escapes depth accounting] → Test both protected function and handler under work/allocation/depth/stop failures, nested protection, re-entry and later-effect witnesses. Fail acceptance rather than increasing limits or exposing controls.
- [Shared formatting alters existing Console output/credits] → Preserve the shell sink, raw bytes and zero-result behavior; compare exact output and spent credits for equivalent shell calls before/after the refactor.
- [Alias names make safe function labels order-dependent] → Keep `unpack`/`table.unpack` identical and register a stable shared description, verified in cold/warm runs.
- [An old user binding collides with a new built-in] → Mark the narrow breaking case in release/help notes, retain source/graph data, diagnose before guest effects, and require explicit user recovery.
- [Lua 5.2 label is mistaken for full compatibility] → Publish the precise supported inventory and exclusions; test the actual pinned engine instead of a desktop Lua of another version.
- [A headless pass is mistaken for visible output or multiplayer acceptance] → Separate contract, cold-load, native-client and connected-client evidence. No new multiplayer behavior is claimed merely because serialization passes.

## Verification strategy

Extend existing fixtures rather than create another runner:

- `tests/runtime_contract.lua`: both saved forms, global parity/aliases, native raw/tuple/error semantics, forbidden sources/protected targets, fatal protection and warm/cold admission.
- `tests/computer_contract.lua` and `tests/editor_contract.lua`: real validate/save/activate logging, exact entry/return behavior, starter source and failed replacement.
- `tests/shell_contract.lua`: interactive helpers, expression display, prefixes, immutable names, transient versus retained functions, collisions, output failure and Follow-off behavior.
- `tests/computer_cold.lua` and `tests/shell_cold.lua`: completed output not replayed, helper-produced data/aliases, exact old active source, retained collision records and same-tick spent credits in separate engine processes.
- `tests/runtime_budget_engine.lua`: maximum helper inputs and adversarial xpcall/raw work beside a healthy computer under production scheduling and unchanged limits.

Run those fixtures from the exact built archive with the existing `tools/smoke.py` options and both engine modes; current CI already invokes them. Run compiler-cache and current source/editor regressions to detect reservation/ABI drift. Preserve full logs, markers, archive hash and process-exit evidence outside the repo. Existing package/docs checks verify the released surface and example inventory.

Use a copied isolated full-client scene to Validate → Save → Run the maintained starter, view its multi-argument output, mix it with shell output, and inspect actual Console spacing, Follow-off and selection. Do not use the monitor animation runner as proof of Console GUI behavior. Extend the existing `tests/shell_client_engine.lua`/`tools/shell_client.py` setup only as needed during implementation after inspecting their own workflow. Cold save/load is not connected late-join evidence; any multiplayer claim must name an actual synchronized-client check.

## Migration Plan

1. Implement and verify the shared functions, compiler rules and collision handling without changing current data/ABI versions or budget defaults.
2. Update the public supported-global inventory and clear name-collision recovery notes. Preserve existing descriptor programs and old noncolliding declaration/shell records.
3. Test saved fixtures before/after cold load, including colliding records, without load-time writes or startup replay.
4. Package and validate the exact candidate; publish nothing until separately authorized.
5. If reverting code, keep source/state/log records intact. Newly authored programs using added names will fail old compiler validation/reconstruction safely; no automatic source downgrade or destructive schema rollback is introduced.

No material product question remains open. Native message-handler re-entry and wrapper admission are concrete verification gates, not permission to redesign the runtime if they fail.
