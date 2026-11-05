# Bounded native Lua language

A saved computer program contains named function declarations only. API version
1 is implicit:

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

Here `sample()` runs immediately, then `"sample"` receives recurring timer
callbacks. `increment` is private and cannot be registered as a callback.
Validate/Save do not execute the source. Run activates it. Activation queues the
optional exported `start` once. Other names do not subscribe to events implicitly.

`start` is optional. Registrations take declared public names as strings, never
function values or private helper names. A document must export at least one
function, even when it deliberately performs no work.

## Declaration scope and calls

At the top level, declaration documents permit only these elements:

- Simple `function name(...) ... end` exports
- Optional `local function helper(...) ... end`
- Comments
- Semicolons.
 Top-level returns, calls, variable
initializers, assignments, loops, conditionals, `do` blocks, dotted declarations
and colon methods are rejected before activation. Declarations do not execute
their bodies during compilation or reconstruction.

Public and private top-level names must be distinct `[A-Za-z_][A-Za-z_0-9]*`
identifiers, at most 64 bytes. Approved API/library/global names, `print`, excluded
global names (including metatable helpers), `_ENV`, `_G` and the `__tc` prefix
are reserved. At most 64 functions are exported. Private helpers do not use export
slots, but still consume source, compiler, generated-text and native syntax limits.

Exports can refer to each other regardless of declaration order. Private helpers
follow normal lexical scope and self-recursion. Declare them before use. They are
not hoisted. Parameters/body locals shadow exports normally and can be reassigned.
Unshadowed public bindings cannot be reassigned or redefined inside another body.
Other global writes and unknown global reads remain forbidden.

`sample(...)` is an ordinary synchronous call inside the current saved program.
It shares the caller's run, authority and remaining credits, without queuing work
or creating an event. Missing arguments are nil. Supplied tables keep their
ordinary aliases. False values, nil holes, zero results and multiple-return
adjustment follow bounded Lua semantics. An exported value can be passed,
returned, captured by a local closure, placed in a temporary table or called via
`pcall`. Direct/mutual recursion remains bounded. `pcall` cannot suppress fatal
budget or stop control. A direct `start(...)` call runs its written effects but
does not activate a new generation or reset credits.

Queued callbacks instead receive their normal copied event in a fresh environment.
Functions, locals and captured values never persist between callbacks. Use explicit
computer state. Function values cannot enter durable Data, including via
`computer.setState`. No player code executes on load. The exact active source is
reconstructed at synchronized dispatch. Later saved-but-unapplied edits do not
replace it, and reload does not replay startup. The live Console never inherits
these function bindings. Keep complete save/mod backups before changing runtimes.

Handlers support these elements:

- Local declarations/assignment
- Literals/tables
- `if/elseif/else`, `do`, `return` and `break`
- Numeric/generic `for`, `while` and `repeat`
- Local helpers and guest calls.
 Recursion/loops consume enforced work/depth/allocation
credits, not unlimited native time. Lua 5.2 primitive arithmetic, comparisons,
short-circuiting, concatenation and multiple-return/nil-tuple adjustment apply.
Nonfinite values cannot cross state/API boundaries. Use dot calls everywhere.

## Approved globals and libraries

The [live Console](../console.md) is a separate bounded expression/statement mode.
Its saved scratch values are not saved-program locals. Both modes use the same
guards and tick ledger. Consult the generated [global helpers](globals.md),
[math](math.md), [string](string.md), [table](table.md) and [colors](colors.md)
for complete members, argument positions, return arity and restrictions.

## Standard helper signatures

Signatures and domains now come only from the public declaration library and its
[generated type index](types.md). Lua 5.2 names do not imply unrestricted native
libraries, host objects, string-method syntax or permission to bypass runtime guards.

## Printing, raw helpers and error transformation

Use the generated [printing, raw-helper and protected-call reference](globals.md).
Its distinctions include nil tuple positions, defensive versus identity-preserving
errors, Console logging, bounded handler re-entry and fatal control that cannot be
caught. [Common types and errors](common.md) and the [Console guide](../console.md)
cover the corresponding execution and retention boundaries.

New built-ins are reserved public/private top-level declaration names, not ordinary
locals/parameters. An older colliding active
source faults only on synchronized reconstruction, with exact source/state retained.
Rename it. Select Save. Then select Run. Noncolliding old sources retain API 1/compiler 2/
storage 1, without startup replay. A colliding old Console root reports named
`E_UNSUPPORTED` before command effects and retains its graph. Confirm Reset Shell
only when you are ready to discard scratch values. Nested fields are unaffected.

## Excluded features

These features are not available:

- `_ENV`, `_G`, global assignment and generated/private names
- Host globals: `game`, `script`, `remote`, `storage`, `settings`, `defines`, `rendering`
- `require`, `load`, `loadstring`, `loadfile`, `dofile` and package/bytecode/debug
- Coroutines, IO, sockets, OS/wall clock, random/randomseed, `math.huge`, GC control and metatable access
- Goto/labels, Lua 5.3+ syntax and colon calls
- String indexing to reach a host metatable.
 Use `string.sub(s, ...)`, not `s:sub(...)`.
No string match/gmatch/gsub/dump, no non-plain find. Protected namespaces and
facades cannot be mutated or persisted. These are intentional compatibility
boundaries, not invitations to bypass the sandbox.

## Failure and persistence

Source/token/node/nesting/generated-source and compile-work limits apply before
activation. Runtime instrumentation charges loops, calls, table/index movement,
operators and opaque helpers. Exceeding fatal work/depth/allocation limits faults
the run even inside `pcall`. It does not yield or change to an interpreter.
Successful earlier state/KV/configuration/display effects stay committed while
still-owned logic output is cleared. A later explicit Run starts a new generation.

No player source executes on load. Only explicit plain state and validated named
registrations/events persist. Host executable reconstruction occurs during
synchronized work with identical warm/cold admission. Work-unit limits do not
prove real-time latency. See [common rules](common.md), [computer API](computer.md)
and [runnable examples](../examples.md).
