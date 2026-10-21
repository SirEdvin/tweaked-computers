# Expanded Lua base-global contract

Normative companion to the [runtime specification](spec.md) and [computer API](lua-api.md). Applies to saved declaration/descriptor callbacks and the live Console in Factorio 2.0.77, base and Space Age. Acceptance receipts distinguish execution evidence from illustrative source. Existing computer methods, events, service errors, scheduling and persistent Data contracts are unchanged.

## Compatibility target and inventory

Factorio documents a modified Lua 5.2.1 environment, with deterministic native helpers and selected backports. The guest exposes an explicit bounded subset, not everything present in the mod's host environment.

Newly available in both guest modes:

| Global | Kind and signature | Result |
| --- | --- | --- |
| `print` | `print(...)` | No values; one Console entry |
| `xpcall` | `xpcall(fn, handler, ...)` | Success: `true, ...`; ordinary failure: `false, error_value` |
| `rawequal` | `rawequal(a, b)` | One boolean |
| `rawget` | `rawget(t, key)` | One value, including nil |
| `rawset` | `rawset(t, key, value)` | The identical `t` |
| `rawlen` | `rawlen(value)` | One integer length |
| `unpack` | `unpack(t, i?, j?)` | The exact results of existing `table.unpack(t, i, j)` |
| `_VERSION` | Read-only global string, not a function | `Lua 5.2` |

Existing globals remain: `assert`, `error`, `ipairs`, `pairs`, `next`, `pcall`, `select`, `tonumber`, `tostring`, `type`, `math`, `string`, `table`, `colors`/`colours`, `computer`, `peripheral`. No new members are added to those namespaces. Call functions directly with parentheses; no colon convention is introduced.

Every required positional argument must be present, including explicit nil where supported. Fixed-signature raw helpers follow native Lua 5.2 handling of additional arguments; ignored arguments still count toward the guest call's tuple/admission bounds. Missing required arguments and invalid operand kinds are ordinary `E_ARGUMENT` failures. Approved guest values comprise existing primitives, guest-owned tables and approved function/facade values, never arbitrary host objects. This does not widen which values are serializable.

## Printing

- Convert each supplied argument using the existing sandbox `tostring`, including all nil holes. Join with one tab between arguments; do not append a literal trailing newline. An entry is the Console's line/record boundary; newlines already inside arguments remain literal content.
- `print()` appends an empty entry and returns zero values. `print(false, nil, 3)` appends raw bytes `false\tnil\t3` and also returns zero values.
- Preserve existing safe descriptions: plain tables are `table`, protected facades/namespaces are `API handle`, and guest functions are `guest function`; approved built-in functions use stable descriptive labels. Do not use host address-based stringification or a recursive pretty-printer. `unpack` and `table.unpack` share function identity and therefore one stable description; do not promise separate labels for aliases.
- Saved-program output uses the same record path/attribution as `computer.log`. Shell printing retains its `Shell #<command> output: ` attribution. Console expression display uses this same formatter but never invents a nil entry for zero-return expressions.
- Honor `tuple_entries`, `string_bytes`, `console_bytes`, `console_entries`, work and allocation bounds. The complete shell prefix counts against the Console entry byte limit. Preflight formatting and log retention work before appending or evicting anything for this print. An ordinary capacity refusal returns no partial output; a fatal admission refusal cannot be caught.
- Stored raw tabs are preserved; the existing native displayed snapshot substitutes one space per tab. Follow-off, selection, source/input text and log retention behavior remain unchanged.
- There is no chat, stdout, host logfile, monitor redirection or return of written text. `computer.log(text)` retains its original one-string/no-results signature and behavior.

## Raw helpers and identity

`rawget(t, key)`:

- `t` must be a guest-owned plain table, including a defensive snapshot already admitted into guest ownership.
- Use the existing guest key/value domains, except that an explicitly supplied nil or NaN lookup produces one nil, as native Lua does. Oversized or foreign key values remain refused.
- Return the stored value itself, not a Data copy. An absent key returns one nil. False is not absent.

`rawset(t, key, value)`:

- Require a guest-owned plain table and a valid existing guest key: nil and NaN keys are refused. A nil value deletes the entry; false is stored normally.
- Apply trusted-value and table-growth validation, plus existing byte-work/allocation accounting, before the first mutation. Updating or deleting an existing key at full capacity is permitted when all other admissions pass.
- Preserve table/function/facade identities already valid as transient guest values. The function returns the same table, not a copy. Self-reference is valid transiently; ordinary Data storage still refuses cycles/functions/reference keys, while Console retention uses its existing narrower graph contract.
- Refusal leaves all aliases and entries unchanged. This is not a transactional rollback of previous successful calls.

Both functions refuse protected namespaces, peripheral facades and host tables as their table operand. Reading a method through ordinary approved facade indexing remains valid; raw helpers are not a second method-discovery or bypass mechanism.

`rawequal(a, b)` compares approved guest operands without invoking metamethods: same reference is true, equal-content distinct tables are false, nil/false retain their normal meanings, and numeric/string comparisons follow native raw equality. Facade identity comparison is allowed but reveals no contents or host address. Validation and potentially input-dependent string comparison work are paid first.

`rawlen(value)` accepts a bounded string or guest-owned plain table and matches native raw length. String length counts bytes. For non-sequence tables it is a Lua border, not a map-entry count; no stable cardinality across insertion orders is promised. Protected/foreign tables and other operand types are refused. Reuse existing length accounting rather than exposing the host operator unguarded.

`unpack == table.unpack` is true. Both names retain the current bounded unpack domains: default `i=1`, default `j=#t`, explicit `i` from 1 through `table_entries+1`, explicit `j` from 0 through `table_entries`, and at most `tuple_entries` returned values. Explicit ranges preserve nil holes and an empty range returns no values. This alias does not widen those pre-existing index restrictions.

## xpcall and fatal controls

- `fn` and `handler` must be approved function values. Guest local functions, saved-program exports in their own callback and approved captured API methods are usable; callable metatable objects are not. Invalid function operands are ordinary argument errors.
- Invoke `fn` with exactly the supplied trailing arguments, preserving nil holes and aliases. Neither protected execution nor message handling creates another run, dispatch, budget, event or authority context.
- Success returns one true followed by the exact function results. A no-result function yields only true. The status-prefixed result must fit `tuple_entries`, even if the function's unprefixed tuple fitted.
- On an ordinary error, supply the message handler exactly one approved error value. Preserve identity for guest-origin error tables/functions already admitted as guest values. Defensively copy host-origin error records as existing `pcall` does; never hand a private host record to the guest. A handler returning no values contributes one nil; multiple handler results are adjusted to the first. Final ordinary failure therefore has exactly two values: false and that first result.
- Use the native Lua 5.2 protected/message-handler semantics for ordinary failures, subject to the guest's depth/work bounds. If message handling itself fails, native error-in-handler behavior is bounded and its exposed diagnostic is safe; wording is not a cross-version API guarantee. Re-entry while handling errors must be guarded, not an unmetered host recursion path.
- Work/allocation/depth exhaustion, final tuple overflow and saved-program stop remain fatal even under nested protection. If the protected function triggers a fatal control, the guest message handler must not run. If the handler itself triggers one, no subsequent guest handler/effect may run. Never pass, stringify or return the private fatal value to guest code.
- `computer.stop()` stays unavailable in Console; this change does not grant the shell program-lifecycle authority. Fatal Console execution follows the existing shell isolation/cleanup policy.
- Previous successful state writes, peripheral effects and printing are not rolled back by protected or unprotected errors. A handler may perform ordinary admitted guest effects only while execution is not poisoned.

## Errors, lifetime and versioning

- Ordinary invalid argument/ownership/key: `E_ARGUMENT`; capacity/output shape excess: `E_LIMIT`; shell persistence/collision: `E_UNSUPPORTED`; compile-time reserved names: `E_PROGRAM` with original source location.
- Fatal execution/depth/allocation/tuple failures use existing `E_BUDGET` diagnostics; saved-program stop uses existing `E_STOP`. Native ordinary error payloads retain current protected-call conventions, not a newly imposed string-only format.
- Guest helpers are ephemeral and reconstructed only during admitted synchronized execution. They add no events, deadlines, stored function objects or new persistence schema. Keep API 1/compiler representation 2/storage 1 when the generated helper ABI remains unchanged.
- Saved source/state/logs and admitted pending work keep their existing lifecycle. A pre-update declaration name collision faults on reconstruction with source/state retained; a pre-update shell root collision refuses evaluation before effects, retains its graph and points to explicit Reset Shell. Noncolliding nested table keys are unaffected.
- Newly exposed names are reserved as API globals/top-level declaration names. Lexical locals/parameters retain ordinary shadowing. Legacy descriptor handler keys are not global bindings and are not newly forbidden.

## Explicit compatibility exclusions

This change does not add metatables or their inspection, `_G`/`_ENV`, dynamic loading/imports, GC control, debug, host `log`/`localised_print`, Factorio objects, files, OS/network access or coroutines. It does not add patterns, randomness, binary packing, `bit32`, new `math`/`string`/`table` members, string-method syntax or colon calls. These are separate compatibility projects; Factorio availability alone does not establish a safe guest surface.

## Illustrative acceptance programs

These are acceptance inputs; source text alone is not execution evidence.

```lua
function start(event)
  local values = table.pack(false, nil, 3)
  assert(unpack == table.unpack)
  print(_VERSION, unpack(values, 1, values.n))
  local t = {}
  assert(rawequal(rawset(t, "ready", false), t))
  assert(rawget(t, "ready") == false)
  assert(rawlen("hello") == 5)
  local ok, message = xpcall(function()
    error("sample failure")
  end, function(problem)
    return "handled: " .. tostring(problem)
  end)
  assert(ok == false)
  print(message)
end
```

Expected raw entries are `Lua 5.2\tfalse\tnil\t3` and `handled: sample failure`, each once after activation, never during Validate/Save. Save/reload after startup must not add either entry again.

Console retention input: `a = {}; b = a; rawset(a, "self", a); rawset(a, "value", false)`. A later command, including after cold reload, checks `assert(rawequal(a, b) and rawequal(rawget(a, "self"), a) and rawget(a, "value") == false)`.

Adversarial inputs include a protected infinite loop with a handler that would log, a looping/stopping message handler, nested `pcall`/`xpcall`, raw mutation of protected namespaces/facades, full-table growth refusal, exact byte/tuple bounds, maximum string comparisons, and retained-name collisions. None is a passing test until the actual packaged fixture has executed.

## Reference basis

- Factorio 2.0.77 bundled `gameitself/base-2.0.77/factorio/doc-html/auxiliary/libraries.html` and matching official page `https://lua-api.factorio.com/2.0.77/auxiliary/libraries.html`.
- Lua 5.2 reference manual basic functions: `https://www.lua.org/manual/5.2/manual.html#6.1`.
- Lua 5.2 base-library implementation for required-argument/result conventions: `https://www.lua.org/source/5.2/lbaselib.c.html`.

The engine's actual supported behavior and unchanged guard limits are the acceptance target. Reading manuals or host source alone does not prove guest-wrapper behavior.
