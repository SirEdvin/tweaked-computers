# Design

## Context

See [proposal.md](proposal.md) for motivation and confirmed product choices; see [console-shell/spec.md](specs/console-shell/spec.md) and its [Lua contract](specs/console-shell/lua-api.md) for behavior.

Source inspection found these relevant boundaries:

- `scripts/ui/editor.lua:271` builds an output-only Console. `owned` at line 311 validates the exact opened UI, token, visible subtree, and authority. `editor-model.lua:15` checks real entity binding, force, surface, reach, and permissions. Source drafts and presentation state already persist separately from program state.
- `runtime/compiler.lua:197` accepts only a literal handler descriptor. Global reads use an allowlist; global assignments are rejected at line 163. It already emits guarded native Lua, and its exact-source cache replays identical charges. `runtime/sandbox.lua` owns the library, object/proxy, quota, and protected-call boundaries.
- `runtime/computer.lua:171` and `services/peripheral.lua:96` bind services to a currently running program. A wrapper contains closures private to that invocation. Merely saving the wrapper or allowing global assignment cannot implement this feature safely.
- `scheduler.lua:109` dispatches at most one program callback per computer per tick, using durable shared credits. GUI validation already shares those credits; shell submission must not bypass them.
- Logic output ownership uses computer/run IDs (`services/logic.lua:150`); the output authority sweep verifies a running program (`services/peripheral.lua:305`). Monitor synchronization keeps a single program-owned selection (`monitor-presentation.lua:66`). All three need shell-aware ownership, not a forged running computer record.
- `control.lua` deliberately executes nothing on load. The bundled 2.0.77 lifecycle/storage documentation explains that multiplayer joining loads a snapshot, and that functions cannot be persisted. The user accepts save-backed shell values; command history was subsequently removed by explicit approval.
- `openspec list --specs` reports an empty canonical inventory. Earlier in-flight runtime/editor specs and `docs/player/api/language.md` describe no shell, no global assignment, and no print. Those remain correct for saved programs but need a narrowly documented Console exception. Do not edit or archive other changes as a side effect of this proposal.

## Goals / Non-Goals

Goals:

- Reuse the parser, guarded native emitter, sandbox, service implementations, authority checks, Console, and one fair scheduler.
- Make a command's environment serializable and independent of the currently running program without serializing executable state.
- Keep accepted side effects deterministic and quota-accounted, including reconstruction, publication, and failure cleanup.
- Prove the requested focused-key interaction before building a large runtime feature around an unworkable GUI assumption.

Non-goals:

- A general Lua VM, persistent native closures/upvalues, OS/filesystem, module loader, multiline editor, event-driven shell programs, debugger, or access to program locals.
- Changing saved-program language/state semantics, weakening limits, undoing real factory effects, or refactoring unrelated service code.
- Treating headless fixtures, mock keyboard events, software-rendered screenshots, or publication cadence as proof of native key delivery, GPU performance, or connected multiplayer.

## Decisions

### 1. One new capability, not a replacement runtime

Keep all new behavioral requirements under `console-shell`. Add a focused `scripts/runtime/shell.lua` module (proposed new file) to own session lifecycle, pending input, dispatch, and retained values. Reuse compiler/sandbox internals through an explicit shell mode/entrypoint. Tag cache entries by compilation mode; saved programs must never consume a shell validation proof or gain shell globals/print.

Alternative rejected: wrapping every line in a fabricated saved program and activating it. That destroys program independence and ties scratch state to program lifecycle incorrectly.

### 2. Resolve keyboard feasibility first

Keep a native single-line textfield and a visible Execute action. Register `on_gui_confirmed` in `control.lua`; preserve focus on confirmation and use exact element validation. No history inputs or custom keyboard routing are added. No undocumented `LuaGuiElement` keyboard callback or focus-query API is assumed.

The isolated full 2.0.77 feasibility fixture verified native typing, paste, caret movement, Enter and field noninterference. Focused Up/Down suppressed custom inputs; identical bindings worked after defocus. Implementation stopped and the user explicitly approved removing history on 2026-10-18. Evidence is retained outside git under the SH1 task's native-key-gate bundle. No buttons, defocus workflow or terminal emulator replaces it.

The revised acceptance target is native text entry plus Enter/Execute, without command recall. All unrelated acceptance remains unchanged.

### 3. Durable value-only graph, fresh executable environment per command

Add an optional versioned shell record on the existing computer: session identity/generation, encoded globals/value nodes, pending command records, and shell resource ownership. UI input drafts and native caret remain player-local presentation data; only executed globals are shared. Use the existing registry sequence for globally ordered command/session identities, with no native objects/functions in the added records.

Decode the committed graph into fresh guest-owned tables and genuine proxies under the current command's guard. A bounded iterative value codec preserves aliases/cycles and scalar keys. Scalars are finite bounded values; graph references and binding descriptors are private tagged records. Resolve a proxy or captured peripheral method through a host-only weak identity map created by the service factory. A guest table containing the same strings is still an ordinary table, never authority.

During execution, globals and table mutations affect this staging graph. On successful completion, validate and encode the whole reachable graph, then atomically publish the new shell root. Do not write the live graph as individual guest assignments occur. Unsupported retained closures/library references/reference keys fail publication and leave the previous environment intact. Functions can still be local/transient within one line. A finite graph codec is not an instruction interpreter and has no stack/continuation representation.

Retained peripheral descriptors include exact identity, generation, wire, and optional method. Decode without performing peripheral effects; calling any restored method rechecks live authority. Preserve alias identity rather than merging all wrappers with equal descriptors. Give encoded scalar keys a stable type/value traversal order so reconstruction is deterministic. Validate headers, references, counts, and capability identity before trusting a retained graph.

Alternative rejected: memory-only globals, which cannot reconstruct a late joiner. Also reject replaying history to rebuild state: reads may differ and writes would repeat. Avoid a persistent closure compiler merely to support unrequested general-purpose function storage.

### 4. Extend guarded compilation narrowly

Parameterize the existing AST emitter's root/global policy, not its language safety rules. Shell roots accept an expression-list or statement chunk. Reads resolve reserved library names or the staged shell environment; writes target only legal nonreserved shell names, using the same tuple/assignment preflight as lexical and indexed assignments. Preserve Lua right-to-left multi-assignment behavior and alias checks.

Share one tokenizer/parser/emitter work scope across expression and statement attempts. Retry only a parse mismatch, never limit refusal, sandbox rejection, or runtime error. Keep original command source coordinates, including expression wrapping. Native `load` still receives only validated emitted text and a closed guard environment; raw input never executes directly.

Install `print` only in the shell sandbox. Capture return tuples with explicit arity so false, nil, and void calls remain different. Use current guarded `tostring`, not a new unbounded recursive formatter. Every command constructs a fresh guard, so prior poison, depth, authority caches, and service closures cannot leak to another tick.

### 5. Real services with explicit execution ownership

Introduce a small host-only execution principal passed explicitly through computer/peripheral service factories and ownership-sensitive provider operations. It identifies the real computer plus either its program run or its shell session. Program callers default to existing behavior. Never replace `rec.run_id`, pretend the saved program is running, clone a fake computer record, or create a second admission identity.

Refactor the concrete ownership checks found in `runtime/computer.lua`, `services/peripheral.lua`, `services/logic.lua`, and `monitor-presentation.lua`. Keep topology discovery and configurator/KV/monitor operations themselves shared. Logic output owners and presentation lanes must identify the correct principal; older owner records without a kind remain program-owned. Store a shell monitor selection independently of `rec.monitor_sync`; existing exclusive-selection rules apply between program and shell too.

Cleanup takes exact principal identity: program retirement cleans program resources, shell failure/reset cleans shell resources, and physical removal/power loss considers both. Output sweep and presenter liveness must accept a live shell on a stopped but powered computer. Live-wire revocation must include shell-held resources even without program subscriptions. Preserve fail-closed cleanup under shared pressure and the existing fail-safe latency; do not rely on successful guest cleanup.

Synchronous metadata, explicit state, logs, and peripheral APIs remain real. Handler-dependent timers/subscriptions and program stop control are explicitly refused in all direct/facade/captured-method/addressed-call routes. Normal calls must not be replaced by a broad host API bypass. `computer.getState/setState` intentionally access real application state; scratch assignment does not.

### 6. Bounded synchronized ingress and fair dispatch

Text-change events update only a bounded input draft. Confirm/Execute validates the opened Console, current player authority, input bytes, session generation, and queue capacity, then records an ordered pending command exactly once. Store source, command ID, submitting player, originating UI token, and shell generation as plain data. A refused admission preserves the input.

Integrate shell work into the existing rotating computer scheduler rather than executing unbounded source inside a GUI event. At most one program callback or shell command runs per computer per actual tick; when both have work, alternate using a durable work-class preference. Service callbacks before the render phase so monitor writes participate in the existing presentation boundary. Recheck player/UI authority, real current power sample, computer identity, and shell generation immediately before execution. Reset, power loss, and invalidated UI access cancel pending work with a bounded diagnostic; closing one player's UI does not cancel other players' submissions.

Use `runtime.context(rec, tick)` and the existing ledger identity for both work types. Reserve bounded decode/commit/diagnostic overhead before starting guest work, without resetting counters or granting a separate shell allowance. Admission-only deferral can retain the unstarted record. Once execution starts, consume it at most once: a later error does not retry earlier effects. Pending source is data, not a persisted execution stack.

Limits in the Lua contract cover source, graph, queue, and total retained sessions. The implementation must measure/test their maximum accepted envelopes under current compiler/callback/shared caps, including two parse attempts and serialization. Account for graph metadata, private vectors, wrapper construction and string bytes. An accepted maximum must not defer forever because its required reservation exceeds the fresh-tick envelope. Do not increase production budgets to hide a mismatch.

### 7. Command-local failure and explicit lifecycle mapping

A compile failure records a shell diagnostic without changing the environment or existing resource ownership. A runtime/commit failure preserves the previous committed environment and releases only shell-owned transient output/selection; previously completed KV/configurator/model/state writes and printed output remain real. The saved program is never passed to `runtime.fault` for an ordinary shell error. Malformed shared engine state remains an existing host safety concern, not something the shell bypasses.

The existing UI has Run/Apply and Stop, not a separate restart action. This design maps successful Run/Apply and explicit Stop to a fresh shell generation; failed activation does not reset it. Automatic program faults preserve the scratch environment so it can still be used to investigate. Confirmed Reset Shell cancels pending work and clears shell values without touching the program or shared peripheral data. Power loss keeps committed values, cancels pending lines, and clears outputs through normal safety paths.

Do not place shell state in item snapshots, blueprints, settings paste, or clone payloads. Physical identity-preserving upgrades retain it; a new placed identity does not inherit it.

### 8. Keep the Console stable while typing

Extend the existing Console rather than adding another tab. Reserve bottom space for input/Execute and a concise status; put explicit confirmed Reset Shell beside shell controls without duplicating program actions. Keep the original output/detail widgets, Follow behavior, source-location routing, and stale-event guards. Shell diagnostics need their own command identity so Show location never selects an unrelated source line.

Draft state and the native caret are private to each viewer. Refresh/layout changes update output and dimensions without rebuilding the focused input. New GUI actions require exact opened frame/active Console ownership. There are no command-recall shortcuts and no mouse-hover approximation of keyboard focus.

## Risks / Trade-offs

- [Focused arrows are suppressed by Factorio] → Escalation completed; user removed command history. Preserve the native input instead of substituting a different UX.
- [Persistence does not mean arbitrary Lua closure persistence] → Publish the retained-value boundary and immediate diagnostics; retain scalar/table/peripheral workflows without adding a VM or replay engine.
- [Real experiments can affect a running factory] → Label the input as live, document partial external effects on failure, preserve normal protections, and isolate transient resource ownership rather than promise a dry run.
- [Stopped-computer shell access touches program-centric safety paths] → Test real logic ownership, monitor exclusivity, disconnect/power cleanup, and concurrent programs through production ticks, not only a service-map stub.
- [Shared shell is intentionally shared mutable state] → Serialize command execution and show author/command identity; keep only each viewer's unfinished input private. Do not promise private variables on a shared computer.
- [Value reconstruction can cost more than the command] → Bound total retained sessions/graph size, prepay reconstruction/publication, test accepted maxima and same-tick refusals, and keep all existing runtime budgets.
- [Current tests use table-backed players] → Extend those for correctness but separately require real native keyboard/UI and two-client late-join evidence. Headless cold load alone does not close multiplayer acceptance.

## Migration Plan

1. Leave old saves with absent shell fields valid. Initialize additive shell state only during admitted synchronized actions/configuration; no source execution or graph mutation in `on_load`.
2. Version shell records and any new ownership tag. Treat untagged existing owners as program owners. Refuse an unknown shell version with recoverable data intact, without preventing ordinary program execution.
3. Update player language/peripheral/editor documentation to distinguish shell bindings from callback-local facades and the saved descriptor language. Add the new contract paths explicitly to `tools/build.py` and its inventory tests; current packaging only includes selected change contracts.
4. Reconcile the earlier in-flight no-shell statements when those capabilities are promoted, preserving their saved-program constraints. Do not fabricate canonical MODIFIED deltas for nonexistent main specs or archive incomplete changes.
5. For rollback, use a pre-upgrade backup or a tested compatibility path that releases shell-owned resources before returning to an older build. Do not claim that arbitrary downgrade of a save with new ownership/session data is verified.

The sole product revision is the explicitly approved removal of history. It does not relax native-client or multiplayer verification for the remaining feature.
