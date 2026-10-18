# Bounded native Lua language

A whole computer program is one literal descriptor:

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

`start` is optional. Handler names are unique, bounded identifiers and all
registrations refer to declared names, never function values. Only comments/empty
statements may surround the sole literal descriptor return. No dynamic descriptor
keys, extra descriptor keys, module-level effects or helper initialization are
allowed. A fresh environment is constructed for each callback: locals and closures
do not secretly survive; use explicit computer state.

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
The descriptor syntax, global-write prohibition and no-print rule below still
apply to saved handler programs. Both modes use the same guards and tick ledger.

Globals: `assert`, `error`, `ipairs`, `pairs`, `next`, `pcall`, `select`,
`tonumber`, `tostring`, `type`; read-only `math`, `string`, `table`,
`colors`/`colours`, `computer`, `peripheral`. No `print`: use `computer.log`.

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

## Excluded features

No `_ENV`, `_G`, global assignment, generated/private names or host globals
(`game`, `script`, `remote`, `storage`, `settings`, `defines`, `rendering`).
No `require`, `load`, `loadstring`, `loadfile`, `dofile`, package/bytecode/debug,
coroutines, IO, sockets, OS/wall clock, random/randomseed, `math.huge`, raw helpers
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
