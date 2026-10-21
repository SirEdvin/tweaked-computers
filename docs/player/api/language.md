# Bounded native Lua language

A saved computer program uses exactly one of two forms. Plain named functions
are the simpler form; API version 1 is implicit:

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
Validate/Save do not execute the source; Run activates it. Activation queues the
optional exported `start` once. Other names do not subscribe to events implicitly.

The existing literal descriptor remains supported, with no source conversion:

```lua
return {
  api_version = 1,
  handlers = {
    start = function(event)
      computer.log("Ready")
      computer.every(60, "sample")
    end,
    sample = function(event)
      local n = computer.getState("samples") or 0
      computer.setState("samples", n + 1)
    end
  }
}
```

In both forms `start` is optional. Registrations take declared public names as
strings, never function values or private helper names. An explicitly empty legacy
handler table is valid; a declaration document must export at least one function.
Only comments/empty statements may surround the legacy descriptor return; dynamic
descriptor keys and extra descriptor keys remain forbidden. Legacy handlers do
not gain implicit references to their sibling handlers.

## Declaration scope and calls

Declaration documents permit only simple `function name(...) ... end` exports,
optional `local function helper(...) ... end`, comments and semicolons at top
level. Do not mix a descriptor with declarations. Top-level calls, variable
initializers, assignments, loops, conditionals, `do` blocks, dotted declarations
and colon methods are rejected before activation. Declarations do not execute
their bodies during compilation or reconstruction.

Public and private top-level names must be distinct `[A-Za-z_][A-Za-z_0-9]*`
identifiers, at most 64 bytes. Approved API/library/global names, `print`, excluded
global names (including metatable helpers), `_ENV`, `_G` and the `__tc` prefix
are reserved. At most 64 functions are exported. Private helpers do not use export
slots, but still consume source, compiler, generated-text and native syntax limits.

Exports can refer to each other regardless of declaration order. Private helpers
follow normal lexical scope and self-recursion: declare them before use; they are
not hoisted. Parameters/body locals shadow exports normally and may be reassigned.
Unshadowed public bindings cannot be reassigned or redefined inside another body;
other global writes and unknown global reads remain forbidden.

`sample(...)` is an ordinary synchronous call inside the current saved program.
It shares the caller's run, authority and remaining credits, without queuing work
or creating an event. Missing arguments are nil; supplied tables retain their
ordinary aliases. False values, nil holes, zero results and multiple-return
adjustment follow bounded Lua semantics. An exported value can be passed,
returned, captured by a local closure, placed in a temporary table or called via
`pcall`. Direct/mutual recursion remains bounded; `pcall` cannot swallow fatal
budget or stop control. A direct `start(...)` call runs its written effects but
does not activate a new generation or reset credits.

Queued callbacks instead receive their normal copied event in a fresh environment.
Functions, locals and captured values never survive between callbacks; use explicit
computer state. Function values cannot enter durable Data, including via
`computer.setState`. No player code executes on load; the exact active source is
reconstructed at synchronized dispatch. Later saved-but-unapplied edits do not
replace it, and reload does not replay startup. The live Console never inherits
these function bindings. Downgrading after adopting new syntax requires a backup
or explicit conversion/reapplication under a compatible runtime.

Inside handlers: local declarations/assignment, literals/tables, `if/elseif/else`,
`do`, `return`, `break`, numeric/generic `for`, `while`, `repeat`, local helpers and
guest calls are supported. Recursion/loops consume enforced work/depth/allocation
credits, not unlimited native time. Lua 5.2 primitive arithmetic, comparisons,
short-circuiting, concatenation and multiple-return/nil-tuple adjustment apply.
Nonfinite values cannot cross state/API boundaries. Use dot calls everywhere.

## Approved globals and libraries

The [live Console](../console.md) is a separate, bounded evaluation mode: it also
accepts statements/expressions and nonreserved scratch-global assignments, and
provides `print(...)`. Its save-backed values are not saved-program locals.
The saved-program forms and global-write prohibition still
apply to saved handler programs. Both modes use the same guards and tick ledger.

Globals in both modes: `assert`, `error`, `ipairs`, `pairs`, `next`, `pcall`,
`xpcall`, `select`, `tonumber`, `tostring`, `type`, `print`, `rawget`, `rawset`,
`rawlen`, `rawequal`, `unpack`, `_VERSION`; read-only `math`, `string`, `table`,
`colors`/`colours`, `computer`, `peripheral`. `_VERSION` is exactly `Lua 5.2`:
the language family, not a promise of unrestricted libraries or host access.

| Library | Complete members |
| --- | --- |
| math | abs, ceil, floor, min, max, sqrt, fmod, modf, sin, cos, tan, asin, acos, atan, atan2, deg, rad, exp, log, pi |
| string | byte, char, len, sub, lower, upper, reverse, rep, format, find |
| table | concat, insert, remove, sort, pack, unpack |
| colors / colours | 16 colors plus gray/grey and lightGray/lightGrey aliases; [exact constants](monitor.md#colors-and-glyphs) |

These follow bounded Lua-style primitive operations, not arbitrary native-library
fallback. Math validates finite operands/results. Numeric-string arithmetic and
conversion is metered; invalid `tonumber` returns nil. `tostring` never exposes
native addresses. `string.find(s, needle, init, true)` requires **explicit true**
for plain search and returns first,last or one nil. No patterns. `string.sub`/byte
operate on byte indexes, not Unicode; char operands are 0–255. Formatting validates
width/precision/output amplification before work. Large repetition/concatenation
can refuse before allocating output. Table mutation requires guest-owned plain
tables; dense-sequence helpers reject unsuitable inputs. Sort stages before
publication and comparator guest calls consume the same ledger. Pack/unpack and
select preserve nil arity but remain within tuple limits. Iterator exhaustion
returns one nil; absent remove returns one nil. Returned defensive API snapshots
are usable guest tables, not references to service internals.

## Standard helper signatures

`...` below is bounded by tuple_entries (128), including protected status prefixes.
These helpers operate only inside a callback; they grant no persistent/host access.

| Global signature | Returns / behavior |
| --- | --- |
| `type(value)` | Lua type-name string |
| `tostring(value)` | Primitive string or stable descriptive table/function/handle name; no addresses |
| `tonumber(value, base?)` | Number or one nil for invalid conversion; base 2–36 requires string |
| `assert(value, ...)` | value,... if truthy; otherwise raise first message or default |
| `error(value)` | Does not return; raises supplied guest value without a host stack-level API |
| `pcall(fn, ...)` | true,results... or false,error for ordinary failure; fatal budget/stop escapes |
| `xpcall(fn, handler, ...)` | true,results... or false,first handler result (one nil if no result); both callbacks share current admission |
| `print(...)` | No values; one bounded Console entry, safe strings joined with tabs; zero arguments write an empty entry |
| `rawget(t, key)` | One stored value, including nil; explicit nil/NaN keys read as absent |
| `rawset(t, key, value)` | Identical t; nil deletes; key/value/capacity/admission checked before mutation |
| `rawlen(value)` | String byte length or guest-table native border, not map entry count |
| `rawequal(a, b)` | Native equality of approved primitives/identities without copying references |
| `unpack(t, i?, j?)` | Identical function to table.unpack; same bounds and nil holes |
| `select("#", ...)` | Argument count, including nils |
| `select(index, ...)` | Suffix tuple; nonzero integer, negative counts from end |
| `next(table, previous_key?)` | key,value or one nil at end; guest table only |
| `pairs(table)` | Iterator, table, nil; no sorted-order guarantee |
| `ipairs(table)` | Iterator, table, 0; stops at first absent 1-based value |

| Math signature | Returns / domain |
| --- | --- |
| `math.abs(x)`, `ceil(x)`, `floor(x)`, `sqrt(x)` | One finite number |
| `math.min(x, ...)`, `max(x, ...)` | One number; at least one operand |
| `math.fmod(x, y)` | Remainder |
| `math.modf(x)` | Integer part, fractional part |
| `math.sin(x)`, `cos(x)`, `tan(x)` | Trigonometric result, radians |
| `math.asin(x)`, `acos(x)`, `atan(x)`, `atan2(y, x)` | Angle in radians; finite-domain results required |
| `math.deg(x)`, `rad(x)` | Radians→degrees / degrees→radians |
| `math.exp(x)`, `log(x, base?)` | Exponential / logarithm; nonfinite result refused |
| `math.pi` | Read-only numeric constant |

The Math table abbreviates member prefixes: e.g. `ceil` means `math.ceil`.
Numeric-string operands are converted under byte-work admission. Native math
errors/nonfinite results do not become valid Data; no random/seed API exists.

| String signature | Returns / defaults |
| --- | --- |
| `string.len(s)` | Byte length |
| `string.sub(s, i?, j?)` | Byte slice; defaults 1,length; negative indexes from end, clipped |
| `string.byte(s, i?, j?)` | Byte-number tuple; default i=1, j=i; empty range yields zero values |
| `string.char(...)` | String from integer bytes 0–255 |
| `string.lower(s)`, `upper(s)`, `reverse(s)` | Byte-string transform |
| `string.rep(s, n, separator?)` | Repetition with default empty separator; nonpositive n yields empty |
| `string.format(format, ...)` | Bounded formatted string; conversions c,d,i,o,u,x,X,e,E,f,g,G,q,s and literal %% |
| `string.find(s, needle, init?, true)` | first,last byte indexes or one nil; default init=1, plain=true required |

Negative string indexes are relative to length; finite numeric indexes are clipped
using the helper's Lua-style floor/ceiling rules. String inputs/results are at most
16,384 bytes. Formatting can refuse a conservative estimated output even if a
particular formatted result would be shorter. No patterns or Unicode processing.

| Table signature | Returns / defaults |
| --- | --- |
| `table.pack(...)` | Temporary table with slots and n counting nils; not necessarily persistable Data |
| `table.unpack(t, i?, j?)` | Tuple including holes; default i=1, j=#t; bounded indexes/tuple width |
| `table.concat(t, separator?, i?, j?)` | String from dense string/number sequence; defaults empty separator,1,length |
| `table.insert(t, value)` / `table.insert(t, position, value)` | None; append / insert into dense sequence |
| `table.remove(t, position?)` | One removed value or one nil; default final position |
| `table.sort(t, less?)` | None; staged dense-sequence sort, default primitive <; optional guest comparator |

Table helpers require guest-owned plain tables and bounded inventory (1,024 entries).
Pack may contain nil holes plus n, so do not store it as Data without conversion.
Sort failure does not publish a partially sorted target, but comparator effects on
other guest/API state are not a callback-wide transaction. Never depend on hash
iteration order for factory decisions: sort a bounded list when order matters.

## Printing, raw helpers and error transformation

`print("value", false, nil, 3, nil)` stores `value\tfalse\tnil\t3\tnil`
as one entry without an added newline. The displayed Console substitutes one
space per tab; stored bytes remain intact. Tables/functions/handles use safe
descriptions, never addresses or recursive inspection. `unpack` and `table.unpack`
share the stable description `table function`. No chat, stdout or monitor output
is produced. Saved printing uses the existing `computer.log` sink; that API keeps
its one-string/no-results signature. Console printing keeps Shell command prefixes.
Formatting and retention are admitted before appending or evicting; failures
publish no partial entry. Successful earlier output survives later faults.

Raw table operations require guest-owned plain tables, including defensive
snapshots. API namespaces, peripheral facades and foreign tables are refused.
`rawset` preserves aliases, accepts transient self-references, and can replace or
delete at full capacity; nil/NaN write keys are invalid. `rawget` preserves false
versus absent nil. Required positional arguments must be supplied (explicit nil
counts); extra arguments follow native raw-helper behavior and still pay call
bounds. `rawequal` may compare an authentic facade/function with itself without
revealing contents. String comparisons are bounded and metered. None of this
widens Data or Console retention: cycles/functions/reference keys are still
invalid where those persistence domains forbid them. `unpack` keeps i=1..1025,
j=0..1024, defaults 1/#t and at most 128 results, including explicit nil holes.

`xpcall(fn, handler, ...)` requires approved functions. Trailing arguments retain
nil holes and aliases. Success prepends true to exact results, including zero
results; status counts toward the 128-value limit. On ordinary failure the handler
gets one safe error: guest references retain identity; host diagnostic records
are defensively copied. Only its first result is returned after false, including
nil when absent. An ordinary handler error follows native, bounded message-handler
re-entry; exact terminal wording is not guaranteed. Work/allocation/depth/tuple
exhaustion and saved-program stop bypass both protected helpers, never reaching
a guest handler as private control values. No protection rolls back earlier state,
printing or peripheral effects. Console still cannot call `computer.stop()`.

New built-ins are reserved public/private top-level declaration names, not ordinary
locals/parameters or legacy descriptor handler keys. An older colliding active
source faults only on synchronized reconstruction, with exact source/state retained;
rename it and explicitly Save/Run. Noncolliding old sources retain API 1/compiler 2/
storage 1, without startup replay. A colliding old Console root reports named
`E_UNSUPPORTED` before command effects and retains its graph. Confirm Reset Shell
only when ready to discard scratch values; nested fields are unaffected.

## Excluded features

No `_ENV`, `_G`, global assignment, generated/private names or host globals
(`game`, `script`, `remote`, `storage`, `settings`, `defines`, `rendering`).
No `require`, `load`, `loadstring`, `loadfile`, `dofile`, package/bytecode/debug,
coroutines, IO, sockets, OS/wall clock, random/randomseed, `math.huge`, GC control
or metatable access. No goto/labels, Lua 5.3+ syntax, colon calls or indexing a
string to reach its host metatable. Use `string.sub(s, ...)`, not `s:sub(...)`.
No string match/gmatch/gsub/dump, no non-plain find. Protected namespaces and
facades cannot be mutated or persisted. These are intentional compatibility
boundaries, not invitations to bypass the sandbox.

## Failure and persistence

Source/token/node/nesting/generated-source and compile-work limits apply before
activation. Runtime instrumentation charges loops, calls, table/index movement,
operators and opaque helpers. Exceeding fatal work/depth/allocation limits faults
the run even inside `pcall`; it does not yield or switch to an interpreter.
Successful earlier state/KV/configuration/display effects stay committed while
still-owned logic output is cleared. A later explicit Run starts a new generation.

No player source executes on load. Only explicit plain state and validated named
registrations/events persist; host executable reconstruction happens during
synchronized work with identical warm/cold admission. Work-unit limits do not
prove real-time latency. See [common rules](common.md), [computer API](computer.md)
and [runnable examples](../examples.md).
