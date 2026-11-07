# Computer runtime delta

## MODIFIED Requirements

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

### Requirement: Deterministic event dispatch
Computers SHALL process non-reentrant callbacks in deterministic order using simulation ticks, durable queue sequence numbers and a scheduler with bounded host work and fair selection between returning invocations. Ordinary API errors MAY be caught through the documented protected-call facility; fatal host-work refusal and stop control MUST NOT be catchable.

#### Scenario: Shared peripheral writes
- **WHEN** two computer callbacks successfully update the same shared value in one tick
- **THEN** the later operation in the documented dispatch order wins identically on all peers.

#### Scenario: Callback failure is not a transaction rollback
- **WHEN** a callback completes one valid database update and then raises an uncaught ordinary error
- **THEN** the update remains committed, the run faults and its owned logic output is cleared
- **AND** the diagnostic identifies the failed source location.

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

## REMOVED Requirements

### Requirement: Bounded native work
**Reason**: Trusted execution withdraws guest-operation and temporary-value containment.
**Migration**: Use the replacement requirements: Trusted native execution and Host-only resource admission. Preserve every retained boundary and persistence contract.

### Requirement: Shared bounded Lua base globals
**Reason**: Trusted execution withdraws guest-operation and temporary-value containment.
**Migration**: Use the replacement requirements: Approved native helper surface. Preserve every retained boundary and persistence contract.

### Requirement: Raw access is confined to guest tables
**Reason**: Trusted execution withdraws guest-operation and temporary-value containment.
**Migration**: Use the replacement requirements: Protected raw table access. Preserve every retained boundary and persistence contract.

### Requirement: Bounded raw comparison length and unpack
**Reason**: Trusted execution withdraws guest-operation and temporary-value containment.
**Migration**: Use the replacement requirements: Native raw comparison and unpack. Preserve every retained boundary and persistence contract.

### Requirement: Extended globals cannot defeat fatal admission
**Reason**: Trusted execution withdraws guest-operation and temporary-value containment.
**Migration**: Use the replacement requirements: Stop and host-boundary faults remain final. Preserve every retained boundary and persistence contract.

## ADDED Requirements

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
