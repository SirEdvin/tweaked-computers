# Bounded native Lua language contract

This is the authorized native-only model. It is not Lua interpreted in Lua, bytecode execution, a continuation VM, or a promise to support every Lua feature. Source is parsed, validated and instrumented, then executed as native Factorio Lua text. Passing an ordinary `load`/`pcall` is not sufficient safety evidence.

## Accepted document shape

Saved programs contain one or more exported function declarations, optional private local-function helpers, comments and empty statements. Top-level returns, calls, values and control flow are forbidden. Each callback reconstructs fresh ephemeral functions; captured objects never acquire an undocumented lifetime.

Inside a handler, support ordinary local declarations/assignments, literals, bounded tables, `if`/`elseif`/`else`, `do`, `return`, `break`, numeric `for`, generic iteration, `while`, `repeat`, local helper functions and guest function calls. Loops are valid syntax but consume enforced work on every iteration; recursion is valid only within the enforced call-depth/work ceiling. Nested helper closures are ephemeral and cannot be registered as callbacks or persisted as Data. Asynchronous APIs accept a declared handler's name, not a function value.

Support Lua 5.2 arithmetic, comparisons, boolean short circuit and concatenation for their documented primitive domains. Non-finite results cannot cross an API/state boundary. Preserve evaluation order, false/nil distinctions, multiple-return adjustment and nil-containing temporary tuples. A rejected syntax/node produces an original-source diagnostic before activation.

## Exclusions

- `_ENV`, `_G`, host globals, global assignments and access to generated/private names.
- `load`, `loadstring`, `dofile`, `loadfile`, `require`, package facilities, bytecode dumps, debug facilities, coroutines, I/O, sockets, operating-system and wall-clock services.
- Metatable creation/inspection and raw host bypasses (`setmetatable`, `getmetatable`, `rawget`, `rawset`, `rawequal`), userdata/thread manipulation and host object reflection.
- `goto`/labels, Lua 5.3+ syntax, colon-call syntax and indexing a string value as a route to the host string metatable. Use approved `string.sub(s, ...)`-style functions instead of string-method syntax.
- Lua patterns (`string.match`, `gmatch`, `gsub`, non-plain `find`), `string.dump`, unapproved C helpers, uncontrolled random APIs and user-supplied environment tables.
- Writing protected API/library tables or smuggling functions/cycles/metatables into state, event payloads, database values or configuration snapshots.

These exclusions are deliberate v1 compatibility limits, not unfinished features to bypass with unrestricted native evaluation.

## Approved standard surface

Exact v1 globals: `assert`, `error`, `ipairs`, `pairs`, `next`, `pcall`, `select`, `tonumber`, `tostring`, `type`, and the read-only namespaces below. No implicit `print` or `os` namespace; use `computer.log` and `computer.getTick`.

- `math`: `abs`, `ceil`, `floor`, `min`, `max`, `sqrt`, `fmod`, `modf`, `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `atan2`, `deg`, `rad`, `exp`, `log`, `pi`. Finite-domain validation and bounded varargs apply. No `random`, `randomseed`, `huge` or arbitrary host-library fallback.
- `string`: `byte`, `char`, `len`, `sub`, `lower`, `upper`, `reverse`, `rep`, `format`, and `find` only when its explicit `plain` argument is true. Input/output bounds and byte-work admission apply before opaque operations; format width/precision/output amplification are validated.
- `table`: `concat`, `insert`, `remove`, `sort`, `pack`, `unpack`. Tuple arity, dense-sequence requirements, movement and sorting work are bounded. Sort comparisons invoking guest code consume the same callback ledger. Helpers never mutate protected namespaces/handles or host-owned tables.
- `colors` / `colours`: immutable 16-color constants documented in the monitor API. No unlisted CC utility functions are implied.

Safe `tostring` exposes primitive values and stable descriptive names for approved callable/wrapper identities, never native table/function addresses. `tonumber` accepts bounded strings and documented Lua 5.2 base conversion, returning nil for invalid input; it does not silently coerce API argument types. `pairs`/`ipairs`/`next` iterate only guest-owned plain tables or defensive snapshots, never private service state. All return arity follows the approved Lua 5.2 contract.

## Enforced boundaries

Instrumentation must account for function entry/exit, loop iterations, statement/operator work where input-dependent, indexed reads/writes, table creation/growth, argument/return movement, concatenation and helper calls. A host string metatable or captured method must not bypass the approved wrapper. Source token/node/nesting limits and compilation-work limits are enforced before native activation; generated text has its own limit.

Native helpers reserve conservative input/output and movement costs before mutation. Limits cover the largest accepted request, not just average examples. Temporary allocation/call-depth ceilings bound one callback's host-memory pressure. Source parsing and native `load` remain synchronous opaque costs with finite validated input envelopes; their real worst-accepted latency must be measured in Factorio rather than called a proven real-time bound from work counters alone.

Budget state belongs to the synchronized scheduler and survives same-tick save/load. Reconstructing a cold executable cache cannot renew credits or change guest-observable admission compared with a warm peer. `pcall` rethrows private quota/stop controls and every subsequent effect also checks the poisoned-run state. Strings, numeric-string coercion, formatting and table operations cannot obtain unpaid work through native Lua syntax.

## Failure and acceptance

Fatal work/call-depth/allocation exhaustion faults the run; it does not suspend the Lua stack. Earlier committed API effects remain, except host-mandated fail-safe clearing of still-owned logic outputs. Ordinary validation/API errors remain catchable. No hidden interpreter fallback is permitted if the instrumented subset cannot meet its acceptance gates.

Required adversarial cases: infinite/empty loops; direct and mutual recursion; closures returning closures; attempted `_ENV`/generated-name access; dynamic string-method bypass; library mutation; `pcall` swallowing; huge format widths, repetition and numeric-string operands; cyclic state; maximum-width argument/return lists; malicious sort comparators; rejected source beside an interactive computer; and cold/warm cache equality with exhausted same-tick budgets. Test the maximum accepted useful work, not comment-padded source. Passing syntax-only tests is not evidence of these properties.
