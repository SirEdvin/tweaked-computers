# computer-runtime Specification

## Purpose

Run a player's event-driven factory program through bounded native Lua callbacks, retaining explicit application state and deterministic behavior across saves and multiplayer clients.

## Requirements

### Requirement: Native named-handler execution
The saved-program runtime SHALL execute one active source document using named, non-suspending native Lua handlers conforming to `lua-api.md`. It MUST NOT interpret Lua instructions, introduce a VM fallback, expose a filesystem, or emulate an operating-system shell. The independent Console command surface SHALL obey the bounded `console-shell` contract; it does not relax saved-handler syntax, create background callbacks or replace the saved program.

#### Scenario: Start an event-driven program
- **WHEN** the player runs a valid document defining a `start` handler
- **THEN** the computer begins a new run generation and invokes that handler once
- **AND** subsequent callbacks run only for registered events, subscriptions or timers.

#### Scenario: Reject unsupported execution features
- **WHEN** a document requests an unsupported language feature, dynamic code loading, coroutine suspension or forbidden host access
- **THEN** validation reports a source-located diagnostic before activation
- **AND** the previous valid active program is not replaced.

### Requirement: Explicit durable state
Saved handlers SHALL persist application data only through the documented state API. Callback locals and closures MUST NOT become durable state. State reads and writes SHALL defensively copy validated, bounded plain data. Console-only globals SHALL use the separate bounded shell graph and symbolic-binding contract, never saved executable functions or command replay; this exception SHALL NOT expand ordinary Data or saved-handler retention.

#### Scenario: Preserve durable values without leaking aliases
- **WHEN** a callback stores a table, mutates its original table and later reads the stored value
- **THEN** the stored value remains the accepted snapshot and the read produces another independent value.

#### Scenario: Refuse invalid state atomically
- **WHEN** a state write contains a function, host object, cycle, metatable, non-finite number or exceeds a declared limit
- **THEN** the write fails without changing the previous value or other keys.

### Requirement: Cold reconstruction without startup replay
Save/load and multiplayer joining SHALL preserve source revision, run generation, explicit state, timer deadlines, registrations and admitted event order. Loading MUST NOT execute player code, mutate durable state, reset spent same-tick budgets or replay startup effects.

#### Scenario: Reload a running program
- **WHEN** a new Factorio process loads a save containing a waiting running computer
- **THEN** the next synchronized dispatch reconstructs executable handlers from the saved active source
- **AND** retained work resumes without invoking `start` or repeating already completed peripheral writes.

### Requirement: Bounded native work
Source validation, reconstruction, callbacks and host services SHALL retain execution limits. Loops, recursion, opaque library work and guest-created allocation SHALL remain bounded; execution exhaustion SHALL fault the run and invoke fail-safe cleanup. Trusted native circuit inventories SHALL not be refused by generic Data or inventory-proportional admission ceilings. Circuit calls remain metered operations, not permission for unbounded guest execution.

#### Scenario: Infinite loop cannot monopolize the simulation
- **WHEN** a callback loops indefinitely or repeatedly catches ordinary errors
- **THEN** enforced execution admission aborts it within the declared work ceiling
- **AND** its quota failure cannot be swallowed to obtain additional work or peripheral effects
- **AND** unrelated admitted computers remain serviceable.

#### Scenario: Large helper inputs remain charged
- **WHEN** a program attempts maximum-sized concatenation, formatting, table construction, state copying or caller-authored peripheral output
- **THEN** guest work and applicable storage/native domains remain enforced before mutation
- **AND** circuit data is not rejected solely for exceeding a generic table, node, name or transport ceiling.

#### Scenario: Native inventory versus guest workload
- **WHEN** one admitted circuit read returns a large native inventory
- **THEN** the bridge exposes the complete result without imposing a proportional result-copy quota
- **AND** subsequent guest loops, repeated calls, arbitrary allocations and explicit state writes still obey their existing resource protections.

### Requirement: Deterministic event dispatch
Computers SHALL process non-reentrant callbacks in deterministic order using simulation ticks, durable queue sequence numbers and a fair bounded scheduler. Ordinary API errors MAY be caught through the documented protected-call facility; execution faults and stop control MUST NOT be catchable.

#### Scenario: Shared peripheral writes
- **WHEN** two computer callbacks successfully update the same shared value in one tick
- **THEN** the later operation in the documented dispatch order wins identically on all peers.

#### Scenario: Callback failure is not a transaction rollback
- **WHEN** a callback completes one valid database update and then raises an uncaught ordinary error
- **THEN** the update remains committed, the run faults and its owned logic output is cleared
- **AND** the diagnostic identifies the failed source location.

### Requirement: Simulation timers and bounded queues
Timers SHALL use simulation ticks, persist deadlines and address named handlers. One-shot timers SHALL fire at most once; recurring timers SHALL not replay unbounded missed intervals. Event backlog SHALL remain bounded with visible fault-on-overflow behavior. Native circuit snapshot size SHALL not consume generic guest-payload byte/node capacity; circuit notifications SHALL still consume queue entries and bounded envelope accounting.

#### Scenario: Paused game and closed save
- **WHEN** simulation ticks do not advance
- **THEN** timer deadlines do not advance through wall-clock time.

#### Scenario: Overdue timer after a power interruption
- **WHEN** a powered-down computer regains power after recurring deadlines passed
- **THEN** at most one overdue event per timer is admitted with its missed-interval count
- **AND** the next deadline remains aligned to the original interval.

#### Scenario: Large observation fits an otherwise available queue
- **WHEN** a trusted circuit notification has more native signal data than generic Data/peripheral payload ceilings allow, but a queue entry and its envelope fit
- **THEN** its complete observation is retained and delivered without a size-induced fault or truncated arrays.

#### Scenario: Slow consumer still reaches backlog protection
- **WHEN** pending notifications exhaust the existing queue entry or envelope allowance
- **THEN** the existing visible overflow fault and output cleanup occur
- **AND** no unlimited backlog, drop-newest policy or suspension mechanism is introduced.

#### Scenario: Cold delivery preserves the accepted observation
- **WHEN** a save contains accepted subscriptions and large undispatched circuit events
- **THEN** cold load retains their observation data, ordering and run identity without startup or output replay
- **AND** subsequent dispatch does not reintroduce a generic payload ceiling or use retained observations to answer fresh reads.

### Requirement: Stop and power semantics
Explicit stop or fault SHALL cancel the run's pending events, timers and subscriptions while retaining source and persistent state. Power loss SHALL pause execution and clear owned logic outputs. Power restoration SHALL resume the same run with current-input resynchronization, without startup replay.

#### Scenario: Safe resumption after brownout
- **WHEN** a running computer loses and later regains electric power
- **THEN** no callbacks execute while unpowered, obsolete signal/touch notifications do not drive stale actions after restoration, and current input is resynchronized
- **AND** retained durable data and timer deadlines are not reset.

### Requirement: Guest trust boundary
Guest code SHALL receive only approved APIs and isolated plain values. It MUST NOT obtain Factorio LuaObjects, host state, filesystem/network access, mutable standard libraries or private budget/authority mechanisms. Every API operation SHALL recheck authority. Fresh detached native circuit records can be transferred without generic defensive recopying; shared baselines and queued events SHALL remain isolated from guest mutation.

#### Scenario: A captured peripheral method outlives its connection
- **WHEN** guest code retains a wrapped method and the valid same-color path is removed
- **THEN** calling that method fails without reading or mutating the disconnected device.

#### Scenario: Native signal tables are usable and isolated
- **WHEN** a guest indexes or iterates a native signal collection beyond former table limits and mutates an existing signal entry
- **THEN** ordinary guest table access works without altering native circuits, output configuration, another consumer or retained event baselines.

#### Scenario: Trust cannot be forged or reused for arbitrary data
- **WHEN** guest data imitates a signal event, adds functions/cycles/host-like fields to a returned table, or passes a result to ordinary state/KV storage
- **THEN** no user-controlled marker grants trusted native treatment and normal argument/storage validation still applies
- **AND** a caller-supplied output replacement is validated even if originally derived from a native read.

#### Scenario: Reuse a native-sized array as caller input
- **WHEN** a guest replaces existing entries of a native-sized array with their signal identities and submits it as a subscription filter
- **THEN** non-growing replacement is not rejected by the old table-entry ceiling, and the complete caller-supplied filter is validated at registration
- **AND** this does not exempt arbitrary new guest allocation or storage from its existing protections.

### Requirement: Versioned executable and data contracts
The runtime SHALL identify its API/source ABI and storage schema. Unsupported retained versions SHALL stop safely with source/state preserved and actionable diagnostics instead of silently resetting data or falling back to another execution model.

#### Scenario: Unsupported retained program representation
- **WHEN** a loaded save contains an incompatible active-program representation
- **THEN** the affected computer remains stopped/faulted with recoverable source and state
- **AND** other compatible computers continue operating.

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
- **AND** Follow-off keeps output live without automatic scrolling, under the Console's accepted changed-text selection-reset and existing eviction rules.

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
