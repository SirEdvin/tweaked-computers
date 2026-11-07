# computer-runtime Specification

## Purpose

Run a player's event-driven factory program through bounded native Lua callbacks, retaining explicit application state and deterministic behavior across saves and multiplayer clients.

## Requirements

### Requirement: Native named-handler execution
The saved-program runtime SHALL execute one active function-declaration document using named, non-suspending native Lua handlers conforming to the `program-source` contract and `api/computer.d.lua`. It MUST NOT interpret Lua instructions, introduce a VM fallback, expose a filesystem, or emulate an operating-system shell. The independent Console SHALL obey the trusted `console-shell` contract; it does not relax saved-handler syntax, create background callbacks or replace the saved program.

#### Scenario: Start an event-driven program
- **WHEN** the player runs a valid document defining an exported `start` function
- **THEN** the computer begins a new run generation and invokes that handler once
- **AND** subsequent callbacks run only for registered events, subscriptions or timers.

#### Scenario: Reject unsupported execution features
- **WHEN** a document requests an unsupported language feature, dynamic code loading, coroutine suspension or forbidden host access
- **THEN** validation reports a source-located diagnostic before activation
- **AND** the previous valid active program is not replaced.

#### Scenario: Validate and reconstruct the same language
- **WHEN** a saved candidate is validated for activation or an accepted active source is reconstructed for dispatch
- **THEN** both operations enforce the same declaration-only grammar and named-handler rules
- **AND** neither stored metadata nor caller-supplied generated text bypasses source validation or selects another execution path.

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

### Requirement: Deterministic event dispatch
Computers SHALL process non-reentrant callbacks in deterministic order using simulation ticks, durable queue sequence numbers and a scheduler with bounded host work and fair selection between returning invocations. Ordinary API errors MAY be caught through the documented protected-call facility; fatal host-work refusal and stop control MUST NOT be catchable.

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
- **WHEN** an upgrade resumes a legacy electrically paused run whose recurring deadlines have passed
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

### Requirement: Guest trust boundary
Guest code SHALL receive only approved APIs and isolated plain values. It MUST NOT obtain Factorio LuaObjects, host state, filesystem/network access, mutable standard libraries or private budget/authority mechanisms. Every API operation SHALL have current authority. Stable proofs can be reused only under the callback-local authority contract. Local output SHALL remain bound to its admitted execution owner. Fresh detached native circuit records can be transferred without generic defensive recopying; shared baselines and queued events SHALL remain isolated from guest mutation.

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
- **AND** this does not exempt explicit storage or caller-authored API requests from their existing protections.

#### Scenario: Local logging does not reacquire peripheral authority
- **WHEN** an admitted callback appends valid local output without an intervening authority-invalidating operation
- **THEN** logging uses the current execution owner without another physical peripheral or owner discovery
- **AND** the caller cannot select another computer, run, or Console session as its output destination.

#### Scenario: Revoked execution cannot keep logging
- **WHEN** stop, fatal host-work refusal, owner retirement, or an authority-invalidating operation ends the execution's authority
- **THEN** a captured print or log callable cannot append another guest entry
- **AND** protected calls cannot hide that retirement or obtain a replacement execution context.

### Requirement: Versioned executable and data contracts
The runtime SHALL identify its API/source ABI and storage schema. Unsupported retained versions SHALL stop safely with source/state preserved and actionable diagnostics instead of silently resetting data or falling back to another execution model.

#### Scenario: Unsupported retained program representation
- **WHEN** a loaded save contains an incompatible active-program representation
- **THEN** the affected computer remains stopped/faulted with recoverable source and state
- **AND** other compatible computers continue operating.

### Requirement: Program print uses the computer Console
`print(...)` SHALL synchronously append one entry to the current computer's bounded Console, converting arguments with the existing safe `tostring`, joining them with tabs, and returning no values. Zero arguments SHALL append an empty entry. `computer.log(text)` SHALL retain its string-only input, exact program argument count, and zero-result contract. Both routes SHALL use bounded local-output and host-work admission. Program printing SHALL NOT emit Factorio chat, host stdout or host log output.

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
- **WHEN** conversion, host-work admission or the complete entry byte bound refuses a print invocation
- **THEN** that invocation publishes no partial print entry and performs no print-driven eviction
- **AND** ordinary diagnostics and already completed earlier output retain their existing behavior.

#### Scenario: Existing retention and failure semantics apply
- **WHEN** a callback successfully prints and subsequently faults, or later output fills the rolling Console
- **THEN** the successful entry is not rolled back and is subject only to the existing retention policy
- **AND** Follow-off keeps output live without automatic scrolling, under the Console's accepted changed-text selection-reset and existing eviction rules.

#### Scenario: Empty entries remain bounded
- **WHEN** a program repeatedly appends empty entries
- **THEN** the existing Console entry bound applies even when the retained text uses no bytes
- **AND** the byte and entry limits both remain effective for later nonempty output.

#### Scenario: One append evicts several old entries
- **WHEN** a fully admitted entry requires removal of an old prefix to satisfy the byte or entry limit
- **THEN** only the necessary oldest entries are discarded, and all surviving entries retain their text, ticks, and order
- **AND** the truncation indicator and saved array representation retain their existing meaning.

#### Scenario: Refused append preserves retained history
- **WHEN** formatting, complete entry size, or host-work admission refuses an entry while the log is full
- **THEN** that append changes no retained entry, byte count, or truncation flag
- **AND** a separate host fault diagnostic can still follow the existing diagnostic-retention policy.

### Requirement: Protected calls can transform ordinary errors
`xpcall(fn, handler, ...)` SHALL invoke approved functions synchronously in the current trusted invocation. Success SHALL return `true` followed by the function's exact native result tuple. Ordinary failure SHALL call the handler with one safe error value and return `false` followed by its first result, including nil. Host-origin error records SHALL be copied before exposure. Existing ordinary side effects SHALL NOT be rolled back.

#### Scenario: Forward arguments and success arity
- **WHEN** a function receives arguments containing false and nil through `xpcall` and returns a nil-containing tuple or no values
- **THEN** argument/result positions are preserved, the success status is prepended and the error handler is not called
- **AND** no mod tuple ceiling applies to the final status-prefixed tuple.

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
- **THEN** protected error handling follows native Lua 5.2 failure behavior within native Lua limits, without a mod execution/depth bound
- **AND** any ordinary terminal error-in-handler diagnostic contains no host objects, private sentinel or generated-source dump.

### Requirement: Demand-driven computer service
A computer SHALL receive recurring execution service only while it has admitted program events or Console submissions. Waiting with no queued work SHALL not cause a timer, dispatch or subscription-discovery visit every tick. Adding unrelated idle computers or devices MUST NOT increase those recurring visits.

#### Scenario: Idle population scaling
- **WHEN** an unchanged active workload is surrounded by additional stopped or waiting computers with no deadlines, subscriptions, owned outputs or open UI
- **THEN** the idle computers receive zero timer, dispatch and signal-work discovery visits; only explicitly due low-frequency physical bookkeeping may visit them.

#### Scenario: Event wakes an otherwise sleeping computer
- **WHEN** an eligible timer, signal, modem, monitor, dashboard or explicit Console submission is admitted
- **THEN** the destination becomes runnable without discovering it through a full registry scan and the admitted item executes at most once.

#### Scenario: Fair competition and reentrant producers
- **WHEN** programs and Console submissions compete while a handler produces more events
- **THEN** each computer receives at most one executable item per actual tick, program/Console arbitration and fair neighbor service remain bounded, and no callback executes inside its producer.

#### Scenario: Queue drained or run retired
- **WHEN** dispatch empties a queue or stop, fault, replacement, removal or authorization retirement cancels its work
- **THEN** the affected execution membership is removed; later valid work wakes the correct generation without reviving canceled items.

### Requirement: Deadline-driven simulation timers
Future timers SHALL cause no per-computer per-tick search. Due timers SHALL preserve per-computer deadline/creation ordering, cancellation, aligned recurring deadlines, missed-interval coalescing and existing budgets. Dispatch may be later than admission; simulation time remains authoritative.

#### Scenario: Far future deadline
- **WHEN** a running computer has only a far-future timer
- **THEN** ticks before its due deadline do not visit that computer to check its timers; the deadline is not delayed by its previous idleness.

#### Scenario: Cancellation and replacement
- **WHEN** a timer is canceled, its run ends, or its recurring deadline advances
- **THEN** obsolete deadlines cannot fire or leave unbounded retained cancellation history.

#### Scenario: Admission pressure
- **WHEN** a timer is overdue or already has an undispatched recurring event
- **THEN** due work remains represented under budget deferral, recurring events coalesce with the original scheduled tick and missed count, and unrelated due/runnable computers retain fair opportunities.

### Requirement: Electricity-independent computer lifecycle
Computers SHALL consume no electricity and SHALL execute without an electrical network. Stop and fault SHALL cancel the run's events, timers and subscriptions and clear only its still-owned transient resources while retaining source and explicit state. Electrical supply changes SHALL not pause, restart, cancel or resynchronize execution.

#### Scenario: No electrical connection
- **WHEN** a valid computer is placed without electrical coverage and explicitly started
- **THEN** its startup, timers, signals and Console operate under ordinary authority, host-work admission, and trusted execution policy.

#### Scenario: Factory power cycle
- **WHEN** electricity near a running computer disappears and returns
- **THEN** run identity, queues, deadlines and state remain unchanged; no startup replay, transient discard or artificial signal resync occurs.

#### Scenario: Last writer still owns cleanup
- **WHEN** a computer stops or faults after another computer has overwritten its output
- **THEN** only resources still owned by the retiring run are cleared; the newer writer remains authoritative.

### Requirement: Durable work membership
Save/load SHALL preserve runnable order, deadlines, active observations, pending maintenance and spent credits without startup replay or authoritative mutation in load callbacks. One-time versioned migration SHALL build missing memberships before ordinary ticking. Stale identity/generation entries MUST NOT authorize work.

#### Scenario: Cold load with mixed work
- **WHEN** a save contains idle devices, queued commands/events, canceled timers, active subscriptions and pending presentation
- **THEN** each valid item continues once in deterministic order, idle devices remain unscheduled, canceled work stays canceled and same-tick credits do not renew.

#### Scenario: Late joining peer
- **WHEN** a peer joins while queued work and shared deadlines exist
- **THEN** all peers derive identical work order and effects from synchronized retained state, not a process-local rebuilt queue.

#### Scenario: Unsupported scheduling representation
- **WHEN** retained scheduling data cannot be safely validated
- **THEN** affected execution stays inert with an actionable diagnostic and preserved source/data, without resetting ledgers or silently rebuilding from untrusted metadata.

### Requirement: Inert legacy power-restoration registration
The existing `power_restored` registration name SHALL remain accepted for source/save compatibility, but custom computers SHALL generate no new power-restoration events. Such registrations SHALL create no observation or scheduling work. Already admitted events SHALL retain ordinary queue ordering and cancellation semantics; migration MUST NOT fabricate a restoration event.

#### Scenario: Existing program registers power restoration
- **WHEN** existing source or a retained run registers `power_restored`
- **THEN** registration and explicit cancellation retain their documented return behavior, but electrical changes cause no polling or notification.

#### Scenario: Previously admitted restoration event
- **WHEN** an old save already contains an admitted `power_restored` callback
- **THEN** it remains an accepted historical queue item subject to normal dispatch/cancellation, and the upgrade creates no duplicate event.

### Requirement: Deterministic revised resource accounting
The runtime SHALL permit revised internal charges and quota-failure positions without increasing resource ceilings. The same runtime version, input, settings, and remaining credits SHALL produce equal admission outcomes with warm or cold host caches. Completed effects and spent credits SHALL remain authoritative. Clock measurements and process-local cache history MUST NOT determine admission.

#### Scenario: Costs differ from an earlier version
- **WHEN** the revised runtime executes a program close to a resource ceiling
- **THEN** its charged amount and first E_BUDGET location can differ from an earlier version
- **AND** successful effects remain in execution order, a refused effect does not occur, and already completed effects are not rolled back or replayed.

#### Scenario: Optimized accounting preserves warm and cold refusal
- **WHEN** identical input starts with identical remaining credits under warm and cold helper or compiler caches
- **THEN** both executions accept the same operations, retain the same paid prefix, and refuse at the same new accounting boundary
- **AND** cache warmth grants neither free work nor additional authority.

#### Scenario: Shared pressure survives settings changes and reload
- **WHEN** program, Console, and maintenance work have consumed credits and a live setting changes or the save is cold-loaded
- **THEN** admission uses the current ceilings and authoritative spent counters without renewal or refunds
- **AND** a lowered allowance refuses new work when the remaining allowance is insufficient.

#### Scenario: Combined reservations cannot cross a completed effect
- **WHEN** several private reservations are combined into one bounded admission unit
- **THEN** refusal occurs before that unit's effects, and successful earlier units remain committed
- **AND** no operation executes on credit that a later check can refuse.

### Requirement: Trusted native execution
Saved callbacks and Console commands SHALL execute ordinary native Lua without operation-level work, allocation, depth, or tuple metering. The runtime SHALL NOT promise interruption of runaway scripts or containment of temporary memory. Host and persistence boundaries SHALL retain their specified checks.

#### Scenario: Finite work beyond the old execution allowance
- **WHEN** a valid invocation performs finite pure Lua work beyond the former callback allowance
- **THEN** it completes without a synthetic execution-budget fault
- **AND** a later device or persistence operation still requires its own admission and authority.

#### Scenario: Native temporary values
- **WHEN** an invocation creates temporary strings, tables, or result tuples beyond their former mod ceilings
- **THEN** native Lua limits apply without a synthetic size, depth, or allocation fault
- **AND** ordinary Data and Console graph publication still enforce their separate limits.

#### Scenario: Accepted runaway-code risk
- **WHEN** player guidance describes saved execution or Console experimentation
- **THEN** it warns that an infinite loop can stall the game and excessive temporary allocation can exhaust memory
- **AND** it does not describe protected calls, Stop, fair scheduling, or host budgets as a watchdog for running Lua.

#### Scenario: Native failures rather than temporary transactions
- **WHEN** native assignment or a table-sort comparator fails after changing temporary values
- **THEN** the runtime follows native behavior without restoring a staged temporary-table snapshot
- **AND** this does not weaken atomic state writes, device operations, or Console graph publication.

### Requirement: Approved native helper surface
Both modes SHALL expose the existing approved global names and library members. Temporary computations SHALL use native behavior except documented safe formatting and protected-object restrictions. No additional host facility, dynamic loading, metatable access, or library member SHALL become available.

#### Scenario: Same helpers in both execution modes
- **WHEN** either mode uses the existing approved helpers
- **THEN** `_VERSION` remains `Lua 5.2` and `unpack == table.unpack` remains true
- **AND** native numeric results and native library errors replace temporary-value instrumentation, without widening device numeric domains.

#### Scenario: No new host surface
- **WHEN** source requests `game`, `storage`, `debug`, `_G`, `_ENV`, dynamic loading, metatables, or an unapproved library member
- **THEN** the existing exclusion remains effective before any unauthorized effect.

#### Scenario: Protected libraries remain immutable
- **WHEN** an invocation uses indexing, raw helpers, table helpers, or a captured callable to change an API namespace or facade
- **THEN** the protected operation is refused
- **AND** another invocation cannot observe a modified shared helper or hidden backing table.

#### Scenario: String indexing cannot expose hidden host members
- **WHEN** an invocation indexes a string through a literal, an alias, or a computed member name
- **THEN** only approved string members can be obtained
- **AND** hidden members such as dump, match, gsub, pack, and unpack remain unavailable through that route.

#### Scenario: Guest and host helper scopes remain isolated
- **WHEN** a native comparator or protected error handler enters guest code, or a checked service enters host code
- **THEN** each side receives only its intended string-member scope
- **AND** success, ordinary failure, fatal host refusal, and stop restore the preceding scope without changing later host handlers.

### Requirement: Protected raw table access
Raw helpers SHALL preserve native temporary-table identity, key rules, and return arity. They SHALL reject protected or foreign tables. Temporary growth SHALL have no mod entry or allocation ceiling. Storage validation SHALL remain independent.

#### Scenario: Raw read and write preserve ordinary identity
- **WHEN** a guest inserts false, replaces a value, creates a cycle, or deletes a key with raw helpers
- **THEN** aliases and nil distinctions follow native behavior, and rawset returns the identical table
- **AND** a cycle still cannot enter ordinary persistent Data.

#### Scenario: Missing reads and invalid writes
- **WHEN** rawget uses an absent, nil, or NaN key on a plain table
- **THEN** it returns one nil
- **AND** rawset refuses nil or NaN keys without granting access to protected tables.

#### Scenario: Growth beyond the former temporary ceiling
- **WHEN** a finite invocation grows a temporary table beyond 1024 entries through indexing or rawset
- **THEN** the old table-entry ceiling does not stop that growth
- **AND** passing the table to a bounded persistence API still invokes that API's validation.

### Requirement: Native raw comparison and unpack
Raw comparison, length, and unpack SHALL preserve native identities, sequence borders, nil positions, and exact return counts. Unpack SHALL have no mod tuple or table-index ceiling. Protected-table exclusions and native index/stack limits SHALL remain effective.

#### Scenario: Identity and raw length
- **WHEN** an invocation compares aliases, distinct equal-content tables, or authentic facades, or measures a plain table/string
- **THEN** the helpers return native equality and raw length without copies, address exposure, or map-cardinality promises.

#### Scenario: Wide and empty tuples
- **WHEN** an invocation unpacks more than 128 positions within native limits, including false and nil, or an empty range
- **THEN** both unpack names preserve every position and return count without the old mod tuple ceiling.

### Requirement: Stop and host-boundary faults remain final
Saved-program stop and fatal host-work refusal SHALL escape nested protected calls. Their private control values SHALL NOT reach guest handlers or authorize later effects. Native Lua errors SHALL remain ordinary native failures rather than synthetic quota controls.

#### Scenario: Fatal control from a protected function
- **WHEN** a protected function invokes stop or exhausts host-work admission through an API call
- **THEN** its message handler and subsequent guest effects do not execute
- **AND** existing stop or fault cleanup applies without exposing the private control value.

#### Scenario: Fatal control from a message handler
- **WHEN** a message handler invokes stop or encounters fatal host-work refusal
- **THEN** outer protected calls cannot convert that control into success or continue guest effects.

#### Scenario: Native error handling is not a watchdog
- **WHEN** a message handler performs pure Lua computation
- **THEN** the runtime imposes no mod recursion or execution ceiling
- **AND** a caught native error grants no new host credits.

#### Scenario: Shared host code cannot carry guest state
- **WHEN** callbacks on the same or different computers use the same immutable host helper implementation
- **THEN** mutable bindings, guest functions, authority metadata, errors, and counters remain isolated between invocations
- **AND** a private local reassignment cannot change a later callback's reconstructed source bindings.

#### Scenario: Refused execution does not poison a neighbor
- **WHEN** one invocation faults and another computer or Console command subsequently calls a shared helper
- **THEN** the later invocation uses its own authority, error state, and remaining host credits
- **AND** it receives neither the earlier fatal control nor renewed credits for work already spent.

#### Scenario: Reload preserves completed output and admission
- **WHEN** a save contains successful output, stored data, pending callbacks, and spent host credits
- **THEN** cold load preserves the log, data, and ledger without executing helpers or replaying output
- **AND** later synchronized dispatch uses fresh invocation state without replaying startup or resetting same-tick host credits.

### Requirement: Host-only resource admission
Source validation, reconstruction, API work, and background maintenance SHALL retain deterministic admission. Shared host work and its maintenance reservation SHALL not meter ordinary Lua operations. Warm/cold caches, settings changes, reset actions, and save/load SHALL not renew retained host credits.

#### Scenario: Settings and effective limits
- **WHEN** a player reads common limits or mod settings after upgrade
- **THEN** callback_work, callback_allocations, callback_depth, tuple_entries, and generated_source_bytes are absent from common limits
- **AND** tc-callback-work and tc-callback-allocations are absent from settings
- **AND** retained source, host, maintenance, storage, queue, output, and device limits keep their existing values.

#### Scenario: Boundary-only string and table limits
- **WHEN** a player reads string_bytes or table_entries
- **THEN** documentation identifies a boundary-data allowance, not a cap on ordinary temporary Lua values
- **AND** API-specific and native-circuit exceptions remain unchanged.

#### Scenario: A native loop does not spend host credits
- **WHEN** a finite computation makes no host API call after reconstruction
- **THEN** its Lua operations do not consume host-work credits
- **AND** actual source, API, UI, and maintenance work still consumes its retained allowance.

#### Scenario: Returning invocations retain fair selection
- **WHEN** finite program callbacks and Console commands compete
- **THEN** the existing ready rotation, one item per computer per tick, and program/Console alternation remain effective
- **AND** no estimated full guest-execution reservation delays a neighbor merely because a removed quota once existed.

### Requirement: Pre-execution host admission
Unstarted preparation SHALL defer when earlier work prevents admission of a prefix that fits the full current allowances. A prefix that cannot fit those allowances SHALL fail instead. Once execution starts, a refusal SHALL NOT cause replay.

#### Scenario: Earlier work leaves too few preparation credits
- **WHEN** earlier work leaves too few source or host credits for an unstarted callback's next preparation charge
- **THEN** a prefix that fits the full current allowances defers without faulting the computer or consuming its queued item
- **AND** queue identity, event metadata, run identity, state, and accepted charges remain unchanged except for preparation work already admitted
- **AND** later dispatch rechecks authority and executes the item at most once.

#### Scenario: Preparation cannot fit the full allowance
- **WHEN** a paid preparation prefix plus its refused charge exceeds a full current source or host allowance
- **THEN** the existing budget-failure path applies instead of endless deferral
- **AND** warm and cold source proofs retain equal charges and outcomes.

#### Scenario: Refusal after a callback starts
- **WHEN** host work is refused after the handler begins execution
- **THEN** the invocation faults without retrying its source
- **AND** earlier completed effects remain real and the item cannot execute again.

### Requirement: Compatible guarded-runtime upgrade
Known saved programs and shell graphs SHALL upgrade without source rewriting, startup replay, or data loss. Upgrade SHALL occur through synchronized work, never on_load. Unknown or malformed representations SHALL remain inert with recoverable data and an actionable diagnostic.

#### Scenario: Upgrade an active guarded save
- **WHEN** a supported pre-change save contains a running program, later unapplied source, timers, queued events, and shell values
- **THEN** upgrade preserves their exact identities, source revisions, values, ordering, and deadlines
- **AND** subsequent dispatch uses the original active source with fresh functions, without replaying completed effects.

#### Scenario: Preserve retained accounting
- **WHEN** upgrade encounters a supported ledger with same-tick spent credits
- **THEN** the remaining host allowance does not increase through migration
- **AND** obsolete execution counters do not become active limits or an alternative runtime.

#### Scenario: Unknown or malformed executable metadata
- **WHEN** retained versions, source, exported names, or symbolic descriptors cannot be validated
- **THEN** affected work remains inert with source and accepted data preserved
- **AND** neither caller-supplied generated code nor an old guard backend runs as a fallback.

#### Scenario: Cold load and late joining
- **WHEN** a supported upgraded save is cold-loaded or a client joins
- **THEN** loading runs no player source and changes no authoritative state
- **AND** later synchronized execution retains the same order, copies, ownership, and no-replay behavior.

### Requirement: Removal of superseded execution machinery
The replacement SHALL delete execution-only instrumentation, accounting, wrappers, settings, and obsolete test machinery after their required boundary responsibilities are transferred. No inactive guarded backend, no-op guard compatibility layer, or alternative execution selector SHALL remain. Surviving source, authority, persistence, output, and host-work protections SHALL retain executable tests.

#### Scenario: Production cleanup audit
- **WHEN** the trusted runtime implementation is reviewed and packaged
- **THEN** the instrumenting emitter, operation probes, temporary ownership/depth/tuple meters, staged assignment/sort, and guest-result allocation reservations are absent
- **AND** imports, generated export discovery, settings, and active limit descriptions use the replacement rather than a retained sandbox module.

#### Scenario: Retire guarantees without deleting surviving coverage
- **WHEN** a fixture previously asserted execution-budget termination or temporary-value refusal
- **THEN** it is replaced by finite native-behavior assertions or removed with an explicit supersession record
- **AND** its independent authority, host-admission, persistence, output, and source-validation assertions remain tested.

#### Scenario: Preserve historical evidence
- **WHEN** cleanup removes current runtime machinery and generated documentation inputs
- **THEN** historical change artifacts, immutable test evidence, and unrelated implementation work remain unchanged
- **AND** legacy data recognition exists only for migration, not execution through the retired backend.

### Requirement: Constant idle scheduling
On a tick where no timer is due, no computer is ready and no subsystem has due or pending work, the scheduler SHALL do only constant bookkeeping. It SHALL NOT call any subsystem hook and SHALL NOT allocate Lua memory on that tick. A subsystem hook SHALL run on a tick only when its synchronized readiness reports due or pending work.

#### Scenario: Idle ticks between reports
- **WHEN** one running computer waits for a recurring timer and no other device, subscription, output, monitor, open UI, database expiry or lifecycle work is pending
- **THEN** every tick before the timer is due calls no subsystem hook
- **AND** the Lua memory count is unchanged across each of those scheduler ticks.

#### Scenario: Pending work wakes only its hook
- **WHEN** a lifecycle event, signal subscription, owned output, monitor change, open viewer, database expiry, clone, undo or radar adoption creates work
- **THEN** the owning hook runs on the tick its work is due, in the fixed registration order
- **AND** hooks with no work stay skipped on that tick.

#### Scenario: Readiness survives save, reload and late joining
- **WHEN** a save holds pending or due subsystem work and is cold-loaded or joined by another peer
- **THEN** every peer derives the same readiness from synchronized storage and runs the same hooks on the same ticks
- **AND** no work is lost, run twice or delayed past its due tick.

#### Scenario: Unreadable subsystem state
- **WHEN** a readiness check finds retained state it cannot interpret
- **THEN** the scheduler runs that hook, so the hook's existing validation and diagnostic path applies
- **AND** the readiness check does not repair or discard the state.

### Requirement: Run-scoped host scaffolding reuse
Saved-program callbacks within one computer run MAY reuse host-side scaffolding built for an earlier callback of that run, including the program chunk that the scaffold loaded for that run's source. Reuse SHALL be invisible to the guest and to synchronized state. Each callback SHALL execute the program's declarations again, start with fresh guest globals, locals and upvalues, and rebind current authority, admission and per-callback proofs.

#### Scenario: Guest state stays fresh
- **WHEN** a callback assigns a global, writes a top-level local or mutates a table reachable only from guest code
- **THEN** the next callback of the same run does not observe that value
- **AND** only computer state, queued events and other documented persistence carry data between callbacks.

#### Scenario: Warm and cold scaffolding are equivalent
- **WHEN** the same callback runs with reused scaffolding on one peer and newly built scaffolding on another peer or after reload
- **THEN** both runs charge the same host work, refuse at the same point and produce the same effects and output
- **AND** neither peer desynchronizes.

#### Scenario: Loaded program is reused only within its run
- **WHEN** several callbacks of one run execute with reused scaffolding
- **THEN** the program text is loaded once for that run and each later callback executes the same loaded chunk with fresh declarations
- **AND** a new run, changed source, callback without reusable scaffolding or Console command loads its program again.

#### Scenario: Authority is checked per callback
- **WHEN** a device is removed, rewired or loses its owner between two callbacks of the same run
- **THEN** the later callback applies current authority and topology, not a proof or inventory cached by an earlier callback.

#### Scenario: Scaffolding ends with its run
- **WHEN** the run stops, faults, is replaced, its computer is removed or relevant settings change
- **THEN** later callbacks never reuse scaffolding from the ended run or the previous settings.

#### Scenario: Console commands
- **WHEN** a player runs a Console command
- **THEN** the Console keeps its existing per-command reconstruction and is not affected by saved-program scaffolding reuse.
