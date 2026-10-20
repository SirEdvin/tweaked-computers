# Computer runtime spec delta

## ADDED Requirements

### Requirement: Shared bounded Lua base globals
Saved programs and Console commands SHALL expose `print`, `xpcall`, `rawequal`, `rawget`, `rawset`, `rawlen`, `unpack` and `_VERSION` alongside the existing approved globals, according to `lua-api.md`. `_VERSION` SHALL equal `Lua 5.2`; `unpack` SHALL alias bounded `table.unpack`. This expansion SHALL NOT expose host facilities, metatables, mutable libraries, dynamic code loading or additional standard-library members.

#### Scenario: Use the same helpers in both modes
- **WHEN** a saved callback or Console command reads each added function and `_VERSION`
- **THEN** the functions are available, `_VERSION` is `Lua 5.2`, and `unpack == table.unpack` is true
- **AND** every call uses that execution's existing limits, authority and native guard.

#### Scenario: No unrestricted Lua compatibility claim
- **WHEN** guest code attempts `getmetatable`, `setmetatable`, `collectgarbage`, `load`, `debug`, `_G` or `_ENV` access
- **THEN** the existing unavailability restrictions remain in force
- **AND** documentation distinguishes the Lua language version from the approved guest API surface.

### Requirement: Program print uses the computer Console
`print(...)` SHALL synchronously append one entry to the current computer's bounded Console, converting arguments with the existing safe `tostring`, joining them with tabs, and returning no values. Zero arguments SHALL append an empty entry. `computer.log(text)` SHALL remain unchanged. Program printing SHALL NOT emit Factorio chat, host stdout or host log output.

#### Scenario: Print false and nil in position
- **WHEN** a saved callback evaluates `print("value", false, nil, 3, nil)`
- **THEN** one raw Console entry contains `value\tfalse\tnil\t3\tnil`, with no added trailing newline
- **AND** the displayed snapshot follows the existing tab-to-space presentation rule without altering stored bytes.

#### Scenario: Preserve print return arity and empty output
- **WHEN** a saved callback evaluates `select("#", print())`
- **THEN** the result is zero and exactly one empty print entry is appended
- **AND** no fabricated nil result or duplicate entry is produced.

#### Scenario: Keep reference descriptions safe
- **WHEN** a callback prints a plain table, guest function or authentic API facade
- **THEN** the corresponding existing safe `tostring` description is emitted
- **AND** no host address, internal field traversal or recursive serialization occurs.

#### Scenario: Admit a complete entry before publishing
- **WHEN** conversion, tuple width, allocation, work or the complete entry byte bound refuses a print invocation
- **THEN** that invocation publishes no partial print entry and performs no print-driven eviction
- **AND** ordinary diagnostics and already completed earlier output retain their existing behavior.

#### Scenario: Existing retention and failure semantics apply
- **WHEN** a callback successfully prints and subsequently faults, or later output fills the rolling Console
- **THEN** the successful entry is not rolled back and is subject only to the existing retention policy
- **AND** Follow-off continues to preserve the viewer's selected output snapshot.

### Requirement: Raw access is confined to guest tables
`rawget(t, key)` and `rawset(t, key, value)` SHALL operate only on guest-owned plain tables without invoking metamethods. `rawset` SHALL preserve aliases, return the identical table and delete a key when value is nil. Ownership, trusted-value, key, capacity, work and allocation checks SHALL precede mutation. API facades, namespaces and host-owned tables SHALL be rejected; persistent Data and shell-value restrictions SHALL remain unchanged.

#### Scenario: Raw read and write preserve ordinary identity
- **WHEN** a guest uses `rawset` to insert false, replace a value, create a self-reference and delete a key on a temporary table
- **THEN** reads preserve false versus absent nil, aliases observe the same writes, and each `rawset` returns that same table
- **AND** attempting to store its cycle in ordinary application state still fails without changing stored state.

#### Scenario: Missing reads are not invalid writes
- **WHEN** a guest calls `rawget` with an absent key, nil or NaN on a valid guest table
- **THEN** it receives one nil value
- **AND** `rawset` with nil or NaN as its key is rejected without mutation.

#### Scenario: Raw helpers do not reveal protected contents
- **WHEN** a guest passes `math`, `computer` or a peripheral facade as the table operand of either raw helper
- **THEN** the call fails with an ordinary argument diagnostic
- **AND** no protected field or host backing table is returned or modified.

#### Scenario: Refused growth leaves aliases intact
- **WHEN** insertion would exceed table capacity or admission refuses work or allocation
- **THEN** the table and every alias retain their previous key/value content
- **AND** replacement or deletion at full capacity remains valid when its other checks and budgets pass.

### Requirement: Bounded raw comparison length and unpack
`rawequal(a, b)` SHALL compare approved guest values using native raw equality without copying identities or invoking callbacks. `rawlen(value)` SHALL return native raw string length or guest-table sequence length, not map entry count. Protected or foreign tables SHALL be rejected by `rawlen`. `unpack` SHALL preserve the existing `table.unpack` arguments, result adjustment, nil positions, bounds and admission behavior.

#### Scenario: Compare identities without exposing internals
- **WHEN** a guest compares two aliases, distinct equal-content tables, identical callable values, primitives or an API facade with itself
- **THEN** `rawequal` produces native raw-equality results without exposing protected contents
- **AND** bounded string comparison work is admitted before comparison.

#### Scenario: Length is not a map counter
- **WHEN** a guest measures a byte string, an empty table or a dense sequence with `rawlen`
- **THEN** it receives the corresponding raw Lua length
- **AND** sparse-table length retains native border semantics rather than promising a count of all keys.

#### Scenario: Alias unpack preserves nil-containing tuples
- **WHEN** a guest unpacks an explicitly indexed tuple containing false and nil using either name
- **THEN** return count and every position agree, including empty ranges
- **AND** the existing index and tuple ceilings are identical for both names.

### Requirement: Protected calls can transform ordinary errors
`xpcall(fn, handler, ...)` SHALL invoke approved functions synchronously under the current guard. Success SHALL return `true` followed by the function's exact bounded result tuple. Ordinary failure SHALL call the handler with one safe error value and return `false` followed by its first result, including nil. Host-origin error records SHALL be copied before exposure. Existing ordinary side effects SHALL NOT be rolled back.

#### Scenario: Forward arguments and success arity
- **WHEN** a function receives arguments containing false and nil through `xpcall` and returns a nil-containing tuple or no values
- **THEN** argument/result positions are preserved, the success status is prepended and the error handler is not called
- **AND** the final status-prefixed tuple must fit the existing tuple limit.

#### Scenario: Transform a guest error
- **WHEN** a guest function raises a guest-owned table or scalar and its handler returns multiple values
- **THEN** the handler receives the same approved guest error identity/value
- **AND** `xpcall` returns exactly false and the first handler result; no results from the handler becomes one nil result.

#### Scenario: Handle a native API failure safely
- **WHEN** an approved service raises an ordinary host-created error record during `xpcall`
- **THEN** the guest handler receives a defensive approved copy
- **AND** mutating it cannot change a private host diagnostic or service state.

#### Scenario: Error handling can itself fail
- **WHEN** the error handler fails ordinarily
- **THEN** protected error handling follows native Lua 5.2 failure behavior within the unchanged execution/depth bounds
- **AND** any ordinary terminal error-in-handler diagnostic contains no host objects, private sentinel or generated-source dump.

### Requirement: Extended globals cannot defeat fatal admission
All added helpers, including both `xpcall` callbacks, SHALL use the current per-computer and aggregate execution, allocation, depth and tuple limits. Fatal budget/depth/allocation exhaustion and stop control SHALL remain uncatchable. A fatal control value MUST NOT reach a guest error handler, become a return value or authorize further effects; nested `pcall` and `xpcall` SHALL NOT renew credits.

#### Scenario: Fatal error in the protected function
- **WHEN** the function passed to `xpcall` exhausts a budget or invokes saved-program stop
- **THEN** the guest error handler and subsequent guest effects do not execute
- **AND** the normal fault/stop cleanup occurs without exposing the private control value.

#### Scenario: Fatal error in the message handler
- **WHEN** the error handler loops, recurses past the depth limit, exhausts allocation or invokes saved-program stop
- **THEN** nested protection cannot recover execution or run another error handler with the private control value
- **AND** the current execution ends under the normal fatal policy while other admitted computers remain serviceable.

#### Scenario: Reload preserves completed output and admission
- **WHEN** a save is made after printing and storing data produced by the helpers, with pending callbacks and spent credits
- **THEN** cold load preserves the retained log, data and ledgers without executing helpers or replaying output
- **AND** later synchronized dispatch uses fresh ephemeral helper functions without replaying startup or resetting same-tick budgets.
