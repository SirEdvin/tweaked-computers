## MODIFIED Requirements

### Requirement: Native named-handler execution
The saved-program runtime SHALL execute one active source document using named resumable Lua handlers conforming to `lua-api.md`. Host-managed serializable continuations SHALL preserve the source language without exposing a filesystem, guest coroutine API or operating-system shell. The independent Console command surface SHALL obey the bounded `console-shell` contract; it does not relax saved-handler syntax, create background callbacks or replace the saved program.

#### Scenario: Start an event-driven program
- **WHEN** the player runs a valid document defining a `start` handler
- **THEN** the computer begins a new run generation and invokes that handler once
- **AND** subsequent callbacks run only for registered events, subscriptions or timers.

#### Scenario: Reject unsupported execution features
- **WHEN** a document requests an unsupported language feature, dynamic code loading, guest-controlled coroutine suspension or forbidden host access
- **THEN** validation reports a source-located diagnostic before activation
- **AND** the previous valid active program is not replaced.

### Requirement: Explicit durable state
Saved handlers SHALL persist application data only through the documented state API. Locals, aliases and symbolic closures SHALL survive only as private state of an unfinished continuation, not as application state or an exemption from Data validation. State reads and writes SHALL defensively copy validated, bounded plain data. Console-only globals SHALL use the separate bounded shell graph and symbolic-binding contract, never saved executable functions or command replay; this exception SHALL NOT expand ordinary Data or saved-handler retention.

#### Scenario: Preserve durable values without leaking aliases
- **WHEN** a callback stores a table, mutates its original table and later reads the stored value
- **THEN** the stored value remains the accepted snapshot and the read produces another independent value.

#### Scenario: Refuse invalid state atomically
- **WHEN** a state write contains a function, host object, cycle, metatable, non-finite number or exceeds a declared limit
- **THEN** the write fails without changing the previous value or other keys.

### Requirement: Cold reconstruction without startup replay
Save/load and multiplayer joining SHALL preserve source revision, run generation, explicit state, timer deadlines, registrations, admitted event order and exact suspended invocation progress. Loading MUST NOT execute player code, mutate durable state, reset spent same-tick budgets or replay startup effects.

#### Scenario: Reload a running program
- **WHEN** a new Factorio process loads a save containing a waiting running computer
- **THEN** the next synchronized dispatch reconstructs continuation blocks from saved active source and resumes saved frames at their next uncompleted step
- **AND** retained work resumes without invoking `start` or repeating already completed peripheral writes.

### Requirement: Bounded native work
Source validation, reconstruction, callbacks and host services SHALL have explicit per-computer and aggregate resource protection. Loops, recursion, allocation and opaque library work MUST be bounded. Runtime work exhaustion SHALL suspend/resume; compilation/reconstruction use bounded non-resumable passes. Memory, necessary depth and compilation-work refusal SHALL be recoverable. Pressure alone SHALL NOT fault a run or clear outputs.

#### Scenario: Infinite loop cannot monopolize the simulation
- **WHEN** a callback loops indefinitely or repeatedly catches ordinary errors
- **THEN** enforced execution admission suspends it within the configured work slice
- **AND** its suspension cannot be swallowed to obtain additional work or peripheral effects
- **AND** unrelated admitted computers remain serviceable.

#### Scenario: Large helper inputs remain charged
- **WHEN** a program attempts maximum-sized concatenation, formatting, table construction, state copying or peripheral output
- **THEN** required work and capacity are checked before the affected mutation
- **AND** valid accepted maxima fit the published service envelope.

#### Scenario: Bounded blocks preserve safety without per-primitive checkpoints
- **WHEN** several small operations execute in one conservatively admitted block
- **THEN** work and growth remain bounded, source errors and committed prefixes are preserved, and loops, callbacks and effects cannot bypass admission or Stop
- **AND** an artificial block boundary does not create a new capacity refusal when the operations can safely be split across slices.

### Requirement: Deterministic event dispatch
Computers SHALL process non-reentrant callbacks in deterministic order using simulation ticks, durable queue sequence numbers and a fair bounded scheduler. Ordinary API and hard-resource errors SHALL be catchable; scheduling suspension and stop SHALL NOT be catchable. A suspended invocation SHALL finish or end before its lane starts another callback. Uncaught resource refusal SHALL end only that invocation; unrelated program errors retain existing fault semantics.

#### Scenario: Shared peripheral writes
- **WHEN** two computer callbacks successfully update the same shared value in one tick
- **THEN** the later operation in the documented dispatch order wins identically on all peers.

#### Scenario: Callback failure is not a transaction rollback
- **WHEN** a callback completes one valid database update and then raises an uncaught ordinary error
- **THEN** the update remains committed, the run faults and its owned logic output is cleared
- **AND** the diagnostic identifies the failed source location.

### Requirement: Simulation timers and bounded queues
Timers SHALL use integer simulation ticks, persist deadlines and address handlers by name. One-shot timers SHALL fire at most once. Recurring timers SHALL not replay unbounded missed intervals. Queue exhaustion SHALL drop newest and record loss under resource-policy. A dropped one-shot delivery SHALL retire its timer; recurring deadlines SHALL advance without retry storms.

#### Scenario: Paused game and closed save
- **WHEN** simulation ticks do not advance
- **THEN** timer deadlines do not advance toward delivery through wall-clock time.

#### Scenario: Overdue timer after a power interruption
- **WHEN** a powered-down computer regains power after recurring deadlines passed
- **THEN** at most one overdue event per timer is admitted with the missed-interval count
- **AND** the next deadline remains aligned to its original interval.

### Requirement: Stop and power semantics
Explicit stop or fault SHALL cancel the run's pending events, timers, subscriptions and suspended invocation while retaining source and persistent state. Power loss SHALL pause unfinished execution and clear owned logic outputs. Budget suspension SHALL preserve outputs and SHALL NOT be treated as power loss. Power restoration SHALL resume the same run with current-input resynchronization, without startup replay.

#### Scenario: Safe resumption after brownout
- **WHEN** a running computer loses and later regains electric power
- **THEN** no callbacks execute while unpowered, obsolete signal/touch notifications do not drive stale actions after restoration, and current input is resynchronized
- **AND** retained durable data and timer deadlines are not reset.

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
- **AND** native index domains and resource accounting are identical for both names, without an independent tuple ceiling.

### Requirement: Protected calls can transform ordinary errors
`xpcall(fn, handler, ...)` SHALL invoke approved functions synchronously under the current guard. Success SHALL return `true` followed by the function's exact bounded result tuple. Ordinary failure SHALL call the handler with one safe error value and return `false` followed by its first result, including nil. Host-origin error records SHALL be copied before exposure. Existing ordinary side effects SHALL NOT be rolled back.

#### Scenario: Forward arguments and success arity
- **WHEN** a function receives arguments containing false and nil through `xpcall` and returns a nil-containing tuple or no values
- **THEN** argument/result positions are preserved, the success status is prepended and the error handler is not called
- **AND** the final status-prefixed tuple uses aggregate resource accounting without a fixed tuple-count ceiling.

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
All helpers SHALL share resource accounting. Work suspension and stop SHALL remain private and uncatchable; memory/depth refusal SHALL be recoverable. Protected calls and continuation reconstruction SHALL NOT renew spent credits.

#### Scenario: Fatal error in the protected function
- **WHEN** the function passed to `xpcall` exhausts its work slice or invokes saved-program stop
- **THEN** the guest error handler and subsequent guest effects do not execute
- **AND** work exhaustion suspends without cleanup, while explicit stop performs cleanup; neither exposes private control.

#### Scenario: Fatal error in the message handler
- **WHEN** the error handler loops past its work slice or invokes saved-program stop
- **THEN** nested protection cannot recover execution or run another error handler with the private control value
- **AND** the current execution suspends or stops respectively while other admitted computers remain serviceable.

#### Scenario: Reload preserves completed output and admission
- **WHEN** a save is made after printing and storing data produced by the helpers, with pending callbacks and spent credits
- **THEN** cold load preserves the retained log, data and ledgers without executing helpers or replaying output
- **AND** later synchronized dispatch uses fresh ephemeral helper functions without replaying startup or resetting same-tick budgets.

## ADDED Requirements

### Requirement: Durable invocation checkpoints
Suspended invocations SHALL preserve control location, locals, aliases, closure environments, protected-call state and pending service progress across save/load and late joining. Checkpoints SHALL contain save-safe data, not native functions, threads or LuaObjects. Completed effects SHALL never be replayed.

#### Scenario: Reload halfway through a nested call
- **WHEN** a handler writes a KV value, enters a nested function with aliased tables and suspends before another write
- **THEN** a cold-loaded or joining peer resumes with identical values and performs only the remaining write
- **AND** loading executes no guest code and replenishes no credits.

#### Scenario: Reconstruction cannot fit reduced settings
- **WHEN** a bounded reconstruction pass cannot fit the current resource policy
- **THEN** source, suspended frames and committed state remain intact with a recoverable diagnostic and host control/recovery access
- **AND** no startup or completed effect replays, no partial compiler state becomes trusted code, and a suitable allowance permits reconstruction without resetting handler progress.

### Requirement: Runtime pressure and event-loss introspection
The runtime SHALL expose a defensive snapshot containing wait reason, effective policy, usage and persistent event-drop diagnostics. Diagnostic reads and control actions SHALL have reserved service opportunity under guest resource exhaustion.

#### Scenario: Diagnose a busy computer
- **WHEN** its queue overflows while a handler is suspended
- **THEN** UI and authorized API queries reveal the wait reason and loss count without another queued event or run reset.
