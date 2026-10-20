# Saved-program declaration contract

This normative companion specifies the authoring surface in [spec.md](spec.md), available in 0.1.10 ALPHA. It adds no host API method. Both source forms use the real saved-program compiler, sandbox and activation path; the earlier planning probe is not feature acceptance.

## Forms and names

A saved program uses exactly one form:

1. Legacy: the existing literal `return { api_version = 1, handlers = { ... } }` document, unchanged.
2. Declarations: at least one top-level `function name(parameters) ... end`, with optional top-level `local function helper(parameters) ... end`, comments and semicolons. API version 1 is implicit.

Only simple names are declarations: not `function object.method(...)`, methods with `:`, `name = function(...)`, conditionally defined functions, or declarations enclosed by a top-level `do`. Those forms do not become alternative export mechanisms. Existing supported statements and nested/local functions remain available inside function bodies.

Top-level identifiers are distinct across public and private declarations, use `[A-Za-z_][A-Za-z_0-9]*`, and fit `identifier_bytes`. Neither kind of top-level declaration may use `_ENV`, `_G`, the reserved `__tc` prefix, an approved global/API/library name, `print`, or a global explicitly excluded by the existing saved-program language contract (including host, dynamic-load, raw/metatable, coroutine and IO facilities). Reject ambiguous or forbidden names; never silently rename the user's source. Nested lexical locals retain existing language rules.

Every non-local top-level declaration is exported, including helpers the author elects not to mark local. Exports count against `handler_names` (currently 64). Private helpers do not consume export slots, but remain subject to all existing source, compile, generated-text and native syntax bounds; their capacity is not unlimited.

## Scope and values

- All exported function names are visible to other program functions regardless of declaration order. This is a deliberate module-like source convention, not permission to assign globals.
- Private `local function` helpers follow Lua lexical scope: declare them before functions that use them. They can call themselves and can reference exported functions declared later. Private forward declarations through `local helper` assignments are outside this declaration-only top level.
- Function parameters and body locals shadow names normally. Writes to such genuine lexical bindings remain allowed; writes to an unshadowed public binding remain forbidden.
- Within a callback, referring to an export returns the same guarded function value used by the handler table. Values can be passed, returned, put into temporary guest tables and called through `pcall`; they cannot be persisted through Data-only APIs.
- Every dispatched callback gets fresh function identities, closures, locals and private helpers. No function or captured local survives as application state. Continue using `computer.getState`/`setState` for continuity.

## Invocation

| Operation | Arguments and results | Execution meaning |
| --- | --- | --- |
| `sample(...)` | Exactly the supplied bounded Lua arguments; ordinary scalar/multiple-return adjustment, false/nil holes and zero-return arity | Synchronous call inside the current callback; no copied or synthesized event |
| `local f = sample; f(...)` | Same as direct call | Same ephemeral callable identity and current guard |
| `pcall(sample, ...)` | Existing `true, results...` or `false, error`; tuple bounds include the status value | Ordinary errors catchable; fatal budget/stop controls escape |
| `computer.every(60, "sample")` | Existing interval/name/optional payload signature; returns timer ID | Later callback receives the existing TimerEvent; return values are not scheduler messages |
| `computer.on(event_name, "sample")` / logic `subscribe(options, "sample")` | Unchanged APIs and existing event payloads | Explicit event registration by exported name |

Automatic dispatch still passes one copied event. Direct calls pass no event unless the caller supplies one; an event parameter may therefore be nil. Direct calls retain native argument aliases, not API Data-copy semantics. They do not grant a new budget, new peripheral authority or another run. All runtime/API calls continue to use dots, not colons.

`start` is an optional exported function automatically queued once per successful explicit activation. An ordinary `start(...)` call simply runs that body, including any registrations the author explicitly repeats; it does not activate a new generation. No other name automatically subscribes to an event. A private `local function start` is not the startup handler.

The live Console never inherits these bindings. No `computer.call`, Console `run`, guest file import or external function-invocation API is added.

## Example: immediate work and recurring work

```lua
local function increment(value)
  return value + 1
end

function start(event)
  local total = sample()
  computer.log("Initial sample count: " .. tostring(total))
  computer.every(60, "sample")
end

function sample(event)
  local total = increment(computer.getState("samples") or 0)
  computer.setState("samples", total)
  return total
end
```

Acceptance: Validate and Save have no sampling effects; activation samples once immediately, then the first timer deadline samples once more. `sample()` has no event argument; timer delivery supplies TimerEvent. `increment` is private, `sample` is forward-referenced, and ordinary reload does not rerun `start`. Reapplying explicitly starts another generation while retaining the explicit sample count under existing state rules.

## Diagnostics, limits and compatibility

- Invalid source shape, duplicate/reserved names, forbidden global writes and mixed formats produce `E_PROGRAM` with original source line/column before replacement of the previous run. An excessive declared inventory/source envelope produces the existing `E_LIMIT`; insufficient compilation/reconstruction credits produce the existing `E_BUDGET`.
- Unknown names in function bodies remain compile-time unavailable-name errors; this syntax does not make arbitrary unresolved globals readable.
- Registering a function value, undeclared export or private helper keeps the existing `E_ARGUMENT` behavior. Function values in durable Data remain invalid. Helper runtime diagnostics point to the helper's original source; lifecycle attribution still names the externally dispatched handler.
- No new limits or budgets. Function creation, reference movement, calls, recursion and collection operations pay existing guard admission. Same-source warm and cold compiler proofs must spend identically, including partially refused admission.
- No module-level variables or effects, whether persistent or ephemeral. No implicit `require`, file execution, VM, coroutine, metatable or unrestricted Lua environment.
- Existing descriptor source and saved active programs keep their behavior; they are not rewritten or granted new implicit sibling-function bindings. The two forms share lifecycle and APIs, not necessarily identical compilation cost for different source strings.
- Retain API version 1, compiler representation version 2 and storage schema version 1. Reconstruct from the exact active source on synchronized dispatch, never on load. Switching formats is an ordinary explicit Save/Apply operation; failed candidates preserve the previous run.
