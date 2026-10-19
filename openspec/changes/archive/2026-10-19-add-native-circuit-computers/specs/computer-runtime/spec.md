# Computer Runtime

## Purpose

Run a player's event-driven factory program through bounded native Lua callbacks, retaining explicit application state and deterministic behavior across saves and multiplayer clients.

## ADDED Requirements

### Requirement: Native named-handler execution
The computer SHALL execute one active source document using named, non-suspending native Lua handlers conforming to `lua-api.md`. It MUST NOT interpret Lua instructions, introduce a VM fallback, expose a filesystem, or emulate a shell.

#### Scenario: Start an event-driven program
- **WHEN** the player runs a valid document defining a `start` handler
- **THEN** the computer begins a new run generation and invokes that handler once
- **AND** subsequent callbacks run only for registered events, subscriptions or timers.

#### Scenario: Reject unsupported execution features
- **WHEN** a document requests an unsupported language feature, dynamic code loading, coroutine suspension or forbidden host access
- **THEN** validation reports a source-located diagnostic before activation
- **AND** the previous valid active program is not replaced.

### Requirement: Explicit durable state
The computer SHALL persist application data only through the documented state API. Callback locals and closures MUST NOT become durable state. State reads and writes SHALL defensively copy validated, bounded plain data.

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
Source validation, reconstruction, callbacks and host services SHALL have explicit per-computer and aggregate limits. Loops, recursion, allocation and opaque library work MUST be bounded. Exceeding execution limits SHALL fault the offending run and invoke host-owned fail-safe cleanup.

#### Scenario: Infinite loop cannot monopolize the simulation
- **WHEN** a callback loops indefinitely or repeatedly catches ordinary errors
- **THEN** enforced execution admission aborts it within the declared work ceiling
- **AND** its quota failure cannot be swallowed to obtain additional work or peripheral effects
- **AND** unrelated admitted computers remain serviceable.

#### Scenario: Large helper inputs remain charged
- **WHEN** a program attempts maximum-sized concatenation, formatting, table construction, state copying or peripheral output
- **THEN** required work and capacity are checked before the affected mutation
- **AND** valid accepted maxima fit the published service envelope.

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
Timers SHALL use integer simulation ticks, persist deadlines and address handlers by name. One-shot timers SHALL fire at most once. Recurring timers SHALL not replay unbounded missed intervals. Queue exhaustion SHALL fault the affected run visibly rather than silently discard admitted work.

#### Scenario: Paused game and closed save
- **WHEN** simulation ticks do not advance
- **THEN** timer deadlines do not advance toward delivery through wall-clock time.

#### Scenario: Overdue timer after a power interruption
- **WHEN** a powered-down computer regains power after recurring deadlines passed
- **THEN** at most one overdue event per timer is admitted with the missed-interval count
- **AND** the next deadline remains aligned to its original interval.

### Requirement: Stop and power semantics
Explicit stop or fault SHALL cancel the run's pending events, timers and subscriptions while retaining source and persistent state. Power loss SHALL pause execution and clear owned logic outputs. Power restoration SHALL resume the same run with current-input resynchronization, without startup replay.

#### Scenario: Safe resumption after brownout
- **WHEN** a running computer loses and later regains electric power
- **THEN** no callbacks execute while unpowered, obsolete signal/touch notifications do not drive stale actions after restoration, and current input is resynchronized
- **AND** retained durable data and timer deadlines are not reset.

### Requirement: Guest trust boundary
Guest code SHALL receive only approved APIs and copied data. It MUST NOT obtain Factorio LuaObjects, the host environment, filesystem/network access, mutable standard libraries or private budget/authority mechanisms. Every API operation SHALL recheck current authority.

#### Scenario: A captured peripheral method outlives its connection
- **WHEN** guest code retains a wrapped method and the valid same-color path is removed
- **THEN** calling that method fails without reading or mutating the disconnected device.

### Requirement: Versioned executable and data contracts
The runtime SHALL identify its API/source ABI and storage schema. Unsupported retained versions SHALL stop safely with source/state preserved and actionable diagnostics instead of silently resetting data or falling back to another execution model.

#### Scenario: Unsupported retained program representation
- **WHEN** a loaded save contains an incompatible active-program representation
- **THEN** the affected computer remains stopped/faulted with recoverable source and state
- **AND** other compatible computers continue operating.
