# Saved-program declaration contract

Normative companion to [spec.md](spec.md). A saved program is a declaration-only document. This surface adds no host method and uses the existing saved-program compiler, sandbox and activation path. Unchanged runtime, Data, peripheral and Console contracts remain authoritative for their own APIs.

## Grammar and names

A document contains at least one exported `function name(parameters) ... end`, with optional top-level `local function helper(parameters) ... end`, comments and semicolons. API version 1 is implicit.

Only simple names declare exports: `function object.method(...)`, methods with `:`, `name = function(...)`, conditional definitions and declarations inside a top-level `do` are not export mechanisms. Top-level returns, calls, initializers, assignments, loops and conditionals are invalid. The restriction does not prohibit supported statements, local/nested functions, constructors or returns inside function bodies. Empty/comment-only/private-helper-only documents are invalid.

Public and private top-level identifiers are distinct, match `[A-Za-z_][A-Za-z_0-9]*` and fit `identifier_bytes`. Neither kind may use `_ENV`, `_G`, the reserved `__tc` prefix, an approved API/library/built-in name or a forbidden global from the saved-language contract. This includes `print`, `xpcall`, `unpack` and `_VERSION`. Diagnostics identify the original source; names are never silently renamed. Body-local bindings and parameters retain ordinary lexical shadowing.

Every non-local top-level function is exported, whether or not the author later registers it. Exports consume the existing `handler_names` allowance. Private helpers consume no export slot but remain subject to source, token, compiler, generated-text, native syntax, execution and allocation bounds. No bound is widened by this change.

## Scope and values

- Exported names are visible to all program functions regardless of declaration order, including mutual calls. This does not permit global assignment.
- Private `local function` helpers have normal lexical declaration order and self-recursion. Declare them before functions that use them; they can reference later exported functions. Top-level variable forward declarations are not allowed.
- Parameters and body-local variables can shadow an export or built-in normally. An unshadowed exported binding cannot be reassigned or redefined from inside a callback.
- An exported function has the same guarded callable identity as its corresponding dispatch entry within one callback. It can be passed, returned, placed in temporary guest tables and called through the approved protected-call helpers.
- Each dispatched callback constructs fresh functions, closures, locals and helpers. Explicit application continuity uses `computer.getState`/`setState`, not retained functions or captured locals. Functions remain invalid values for Data-only APIs; failed storage does not mutate the previous value.

## Calls and registration

| Operation | Arguments and results | Execution meaning |
| --- | --- | --- |
| `sample(...)` | Supplied bounded Lua arguments; ordinary scalar/multiple-return adjustment, false/nil holes and zero-return arity | Synchronous call under the current callback; no synthesized event |
| `local f = sample; f(...)` | Same as a direct call | Same ephemeral identity, guard, authority and run |
| `pcall(sample, ...)` | Existing status-prefixed result tuple or safe ordinary error; tuple bounds include status | Ordinary failures are catchable; fatal budget/stop control is not |
| `computer.every(60, "sample")` | Existing interval/name/optional-payload signature; returns a timer ID | Later dispatch supplies its ordinary TimerEvent in a fresh callback environment |
| `computer.on(event_name, "sample")` / logic `subscribe(options, "sample")` | Existing signatures, results and event payloads | Explicit registration by exported name |

Automatic dispatch passes one copied event, with existing trusted-native event rules unchanged. Direct calls pass only their supplied arguments and preserve native argument aliases; they do not apply API Data-copy semantics, create a callback, enqueue work or renew any credits. A direct call with no arguments supplies no synthetic event. Runtime/API methods retain dot-call syntax.

`start` is optional and is queued once per successful explicit activation when exported. Calling `start(...)` explicitly is an ordinary function call; effects and registrations in its body occur, but it does not create a new run. A private `local function start` is not a startup handler. No event-like name subscribes automatically. Registration APIs require an exported name string, not a function value, private helper or nested-function name.

The live Console does not inherit program exports. Its statement/expression syntax, scratch graphs and ephemeral locals remain separate. There is no added external function-invocation method, executable file import, Console program launcher or background callback API.

## Example: immediate and recurring work

```lua
local function increment(value)
  return value + 1
end

function start(event)
  local total = sample()
  print("Initial sample count:", total)
  computer.every(60, "sample")
end

function sample(event)
  local total = increment(computer.getState("samples") or 0)
  computer.setState("samples", total)
  return total
end
```

Validate and Save have no sampling effects. Activation samples once immediately; the first timer deadline samples once more. `sample()` has no event argument; timer delivery supplies TimerEvent. `increment` is private, `sample` is forward-visible, and ordinary reload does not rerun `start`. Explicit reapplication starts another generation while retaining the existing explicit count.

## Errors, admission and lifecycle

| Condition | Existing result |
| --- | --- |
| Invalid top-level statement, missing export, duplicate/reserved declaration, unavailable global or forbidden global write | `E_PROGRAM`, original source line/column, no candidate execution or replacement of the active run |
| Declared source/inventory/generated-text envelope exceeded | Existing `E_LIMIT`; previous active run retained |
| Insufficient compilation or reconstruction admission | Existing `E_BUDGET`; no renewed credits or unguarded retry |
| Invalid name or function value supplied to a named-registration API | Existing `E_ARGUMENT`; no new registration |
| Executable or otherwise invalid value supplied to a Data-only API | Existing Data refusal; previous stored value retained |

Diagnostics in a directly called helper identify that helper's original source location; run/revision/dispatched-handler attribution keeps its existing meaning. Function binding, creation, reference movement, ordinary/protected calls and recursion retain guard admission. For the same source and initial credits, warm and cold cache paths must agree on success, refusal and paid prefixes. Caller-mutated generated text or handler inventories are not executable authority.

Validate, Save and Run/Apply retain their separate effects. Failed candidates preserve the active run, registrations and state. Compatible active sources retain their exact bytes, run identity, explicit state, timer deadlines, pending work and spent same-tick credits across cold reload. Reconstruction occurs only on synchronized dispatch, never during load; startup and completed effects are not replayed. No source conversion, new setting, storage migration or blanket API/compiler-version rejection is introduced.

If an active declaration collides with a newly reserved built-in, normal synchronized reconstruction reports the collision and faults safely while preserving source, explicit state and recovery information. Load itself neither rewrites the source nor executes it. Noncolliding declarations continue without forced restart.
