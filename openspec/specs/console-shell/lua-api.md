# Console Lua shell contract

Target: Factorio 2.0.77, base and Space Age, native Lua API v1. Normative behavior is in [spec.md](spec.md) and the [shared API rules](../../api/common.md); exact verification and limitations are recorded in the retained acceptance receipts. Examples are acceptance inputs, not by themselves execution evidence.

## Entering and evaluating a line

Open the computer through its existing interaction, select Console, and type or paste one line into the bottom input. Enter or Execute submits the same action. There is no command history or Up/Down recall. Existing key bindings outside this input are unaffected.

A line is one synchronous native chunk, with the same bounded statements, loops, local functions, standard helpers, and dot-call convention documented in `docs/player/api/language.md`. Semicolons can separate statements on that line. Literal CR/LF input is refused; there is no multiline continuation mode.

Evaluation first tries to compile an expression list as a return expression. Only a syntax/grammar mismatch permits a statement-chunk attempt; both attempts share one compilation budget. Nothing executes until the chosen parse has passed validation. A runtime error never causes a second evaluation attempt. Explicit `return ...` works in statement mode. Results are displayed with exact tuple arity: one nil is a value; zero returns produce no result entry.

Shell-global names read the shared scratch environment; an undefined nonreserved name yields nil. Assignment creates or replaces a shell value, and assigning nil deletes a binding. `local` variables last only for that submitted chunk. The existing API/library names and `print` are reserved against assignment. `_G`, `_ENV`, private generated identifiers, `game`, `storage`, dynamic loading, host objects, coroutines, and the existing unsupported language constructs remain unavailable. The saved-program compiler is not relaxed.

## Output

`print(...) -> no values`

- Accepts the same bounded tuple width as other guest calls, including zero arguments, false, and nil in any position.
- Converts each argument with the sandbox's stable `tostring` behavior, joins with a tab, and appends one bounded Console entry. Zero arguments append an empty print entry.
- The native displayed snapshot replaces each tab with one space to avoid missing glyphs; raw retained log bytes, print tuple semantics, newlines and byte limits remain unchanged.
- Tables, guest functions, and API handles use stable descriptive text, not host memory addresses; this is not a new recursive table pretty-printer.
- Rejects oversized output before appending a partial entry. Uses the existing console retention limits; older entries may be evicted normally.
- Does not call Factorio chat. Saved programs share this formatter through guarded `computer.log`; shell attribution remains unchanged.

The Console distinguishes command echo, printed/expression output, shell diagnostics, and existing program output. A command sequence and submitting player identify each echo. Diagnostics identify the shell line/column and command, never incorrectly select a line in the saved editor source. Output produced before a later error remains visible. Follow-off keeps the single Console text box live without automatic scrolling. Incoming changed text may clear native selection; native selection/copy works between updates and unchanged text is not reassigned. Re-enabling Follow resumes tailing. There is no Refresh action or separate snapshot view. Existing log bounds and visible truncation still apply while Follow is off; discarded bytes cannot be recovered and unrelated replacement bytes are not reselected. A separate concise command status can report completion without forcing a scroll.

## Retained values

The [expanded base globals](../computer-runtime/lua-api.md#expanded-lua-base-globals) also apply here: guarded rawget/rawset/rawlen/rawequal/xpcall, identical unpack/table.unpack and fixed _VERSION. They grant no program handler/stop authority and no new retained function kinds. A retained root with a newly reserved name (for example rawset or _VERSION) fails before guest effects with named E_UNSUPPORTED and explicit Reset Shell guidance. The old graph/aliases/source/application state/program remain intact; nested keys do not collide. Confirmed Reset Shell discards scratch values through the existing lifecycle, not automatic migration. Failed protected execution cannot publish a staged graph or fault the saved program; earlier successful output/effects remain.

Supported across commands and save/load:

- Boolean, finite number, and bounded string values. Nil removes a binding or table entry.
- Bounded plain table graphs with string, finite-number, or boolean keys; sparse/mixed scalar-key tables, aliases, and cycles are allowed for shell storage. This is not an expansion of the ordinary Data accepted by peripheral/state APIs.
- Genuine protected peripheral facades and captured peripheral methods, including references inside supported tables. These are encoded by private binding identity, name, generation, wire, and optional method name, never as saved functions.

Not supported as retained values:

- User-defined functions/closures, even if a function seems not to capture anything.
- Tables/functions used as table keys, arbitrary metatables, userdata/threads, Factorio objects, or aliases to protected library namespaces and nonperipheral API functions.
- Guest-constructed lookalike records claiming to be handles. Ordinary record fields do not grant a capability.

Local functions and transient values already allowed by the language remain usable within a line. For example, `local function twice(x) return x * 2 end; answer = twice(4)` can commit `answer`; `twice = function(x) return x * 2 end` cannot retain that function. A rejected retention leaves the previous entire shell environment committed. Earlier external effects are not undone.

Supported table identity is preserved across commands/reload. No native execution stacks, closure bytecode, callbacks, or command replay journal are persisted.

## Computer and peripheral APIs

All calls use dots. Existing signatures, argument validation, nil/tuple results, synchronous effects, and service errors remain as documented in `docs/player/api/` except for execution ownership and the exclusions below.

| Surface | Shell behavior |
| --- | --- |
| `computer.getID()`, `getLabel()`, `setLabel(label?)`, `getTick()`, `getLimits()` | Current real computer and current synchronized tick; normal validation/copying. |
| `computer.getState(key)`, `setState(key, value)`, `deleteState(key)` | Explicit access to the real computer's application state, not to shell globals. Writes intentionally affect what the saved program sees. Normal Data restrictions remain. |
| `computer.log(text)` | Append to the current shell command's Console output. |
| `computer.stop()`, `on(...)`, `off(...)`, `after(...)`, `every(...)`, `cancelTimer(...)` | `E_UNSUPPORTED`: use the saved handler program or explicit UI lifecycle controls. No borrowing of program handlers or ownership. |
| `peripheral.getNames(wire)`, `isPresent(name, wire)`, `getType(name, wire)`, `getMethods(name, wire)`, `describe(name, wire)` | Existing discovery and complete snapshot semantics. Explicit `"red"` or `"green"` is required. |
| `peripheral.wrap(name, wire)` | One genuine facade or one nil when absent after complete discovery. A retained facade remains bound to its exact generation/color. |
| `peripheral.find(type_name, wire)` | Existing zero-or-more facades as multiple returns, not a result array. |
| `peripheral.call(name, wire, method, ...)` | Existing addressed synchronous operation and exact result arity; the exclusions below also apply through this route. |
| `peripheral.getName(facade)`, `getWire(facade)` | Inspect an authentic restored facade without granting access to a disconnected target. |
| `peripheral.setMonitorSyncGroup(members)`, `getMonitorSyncGroup()` | Existing behavior owned by this shell session, independent of the saved program. Existing cross-owner `E_BUSY` remains meaningful. |
| Monitor, KV, logic read/output, and configurator synchronous methods | Real operations under their existing contracts, including normal native target protection and power requirements. |
| Logic `subscribe(...)`, `unsubscribe(...)` | `E_UNSUPPORTED` in the shell, including facade, captured-method, and `peripheral.call` routes. No program subscription can be edited. |

Captured methods revalidate the computer, shell generation, bound peripheral generation, force/surface, selected wire, and current power/authority on every call. Rehydrating a stale descriptor does not retarget it. Missing fresh `wrap` returns nil; calling an existing stale wrapper reports the normal `E_UNREACHABLE`/unavailable diagnostic. `getLimits` retains its existing peripheral power exception, but the computer itself must be powered to execute shell code.

There are no shell callbacks/events, timers, handlers, files, imports, OS commands, or shell-driven background tasks. Monitor presentation still uses its existing host coordinator.

## Session lifetime

There is no retained command history. Each admitted nonempty line is echoed once in the bounded Console output, including lines that later fail compilation or execution. Rejected ingress and blank lines are not echoed as commands. Console logs are never replayed.

Each viewer keeps an independent unsubmitted draft and native caret. Tab changes and output refreshes do not replace the input.

| Event | Values | Pending commands and transient resources |
| --- | --- | --- |
| Close/reopen the window | Retain | Cancel that viewer's not-yet-started submissions if the required opened authorization is gone; retain previously established shell resources. |
| Save/load or late join | Retain | Preserve ordered pending records and spent credits; recheck authorization before execution. No command replay. |
| Successful Run/Apply or explicit computer Stop | Clear, new session generation | Cancel old-session work; release old shell-owned logic output/monitor selection. |
| Confirmed Reset Shell | Clear | Cancel shell work/release shell resources only; leave the saved program running. |
| Failed activation or automatic program fault | Retain | No blanket shell reset; do not confuse program cleanup with shell cleanup. |
| Power loss | Retain | Cancel pending lines visibly; clear owned logic output and apply existing monitor power semantics. Do not replay canceled input on restoration. |
| Computer removal, clone, blueprint, mining/replacement | No session transfer to a new identity | Clean up only the removed identity's resources. |

Reset confirmation is tied to the current shell generation. Reset does not erase shared peripheral contents or historical Console logs. Shell variables are distinct from the application-state Reset action.

## Admission, errors, and effects

Proposed initial shell-specific capacities (implementation must verify fitting accepted maxima under unchanged runtime budgets):

| Limit | Proposed value |
| --- | ---: |
| Command source bytes | 4096 |
| Shell global bindings | 64 |
| Retained encoded value accounting units / graph elements | 16384 / 1024 |
| Pending entries / total source bytes per computer | 8 / 16384 |
| Retained shell session records across the world | 64 |

Existing identifier, string, table-entry, tuple, compiler/AST, callback-depth, console, service, per-computer, and aggregate work limits also apply. The shell session cap includes idle retained sessions and has explicit capacity feedback; reset releases a slot. New limits must appear in `computer.getLimits()` and maintained limit documentation. Graph traversal must be iterative/bounded, including cycles and metadata; no unbounded retained source is allowed.

Graph accounting includes scalar/reference edges and private node/binding metadata, not only table identities. Each item costs 16 units plus string bytes. These are conservative logical encoding units, not measured host memory. An admitted session record occupies its slot until reset/Run/Apply/Stop even if its current value graph is empty.

Ingress validates ownership and bounds before adding queue records. Commands execute through the normal scheduler, not on every text-change event. At most one executable work item per computer per tick is selected fairly between pending program and shell work. Pending input is bounded and labeled as queued; no shared budget is replenished to give a GUI command preferential execution.

`E_ARGUMENT` identifies malformed ingress, invalid keys, or forged values; `E_LIMIT` size/shape excess; `E_CAPACITY` retained/pending capacity; `E_UNSUPPORTED` retained functions or handler-only operations; `E_PROGRAM` syntax/runtime failure; `E_BUDGET` exhausted guarded work. Existing service authority, power, and domain errors remain unchanged. Unknown retained shell versions are refused without deleting their data.

A successful line atomically publishes its staged shell environment. Failure preserves the previous environment but not an imaginary rollback of completed API calls. An uncaught execution/commit failure releases this shell's transient output ownership; it does not fault the saved program. Compilation-only failure leaves existing ownership unchanged. Ordinary protected-call recovery behaves as in the current sandbox; fatal quotas remain uncatchable.

## Illustrative acceptance sequence

Replace `tc-42` with the exact reachable monitor name shown by Peripherals; the example does not assert a real fixture ID.

```lua
p = peripheral.wrap("tc-42", "red")
print(p.getSize())
p.setCursorPos(1, 1); p.write("Shell test")
size = p.getSize
print(size())
```

The first two lines exercise shared bindings and printed tuples. Closing/reopening and then a cold reload between the first and second line must retain the binding without repeating effects. Removing the red path before the last line must refuse the captured method. Actual live monitor text, shell/program ownership, and multiplayer joining require engine evidence during implementation.

Additional exact contract inputs: `false`, `nil`, `print(false, nil, 3)`, `x = 5; local y = 6`, `print(x, y)`, `a = {}; b = a; a.self = a`, `b.value = 9`, `print(a.value, a.self == a)`, and `while true do end`. Their expected behavior is specified in the companion scenarios, not claimed tested here.
