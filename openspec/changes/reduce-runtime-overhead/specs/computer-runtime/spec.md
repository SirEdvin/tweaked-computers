# Spec Delta

## MODIFIED Requirements

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
- **AND** this does not exempt arbitrary new guest allocation or storage from its existing protections.

#### Scenario: Local logging does not reacquire peripheral authority
- **WHEN** an admitted callback appends valid local output without an intervening authority-invalidating operation
- **THEN** logging uses the current execution owner without another physical peripheral or owner discovery
- **AND** the caller cannot select another computer, run, or Console session as its output destination.

#### Scenario: Revoked execution cannot keep logging
- **WHEN** stop, fatal exhaustion, owner retirement, or an authority-invalidating operation ends the execution's authority
- **THEN** a captured print or log callable cannot append another guest entry
- **AND** protected calls cannot hide that retirement or obtain a replacement execution context.

### Requirement: Program print uses the computer Console
`print(...)` SHALL synchronously append one entry to the current computer's bounded Console, converting arguments with the existing safe `tostring`, joining them with tabs, and returning no values. Zero arguments SHALL append an empty entry. `computer.log(text)` SHALL retain its string-only input, exact program argument count, and zero-result contract. Both routes SHALL use bounded local-output admission under the revised accounting contract. Program printing SHALL NOT emit Factorio chat, host stdout or host log output.

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

#### Scenario: Empty entries remain bounded
- **WHEN** a program repeatedly appends empty entries
- **THEN** the existing Console entry bound applies even when the retained text uses no bytes
- **AND** the byte and entry limits both remain effective for later nonempty output.

#### Scenario: One append evicts several old entries
- **WHEN** a fully admitted entry requires removal of an old prefix to satisfy the byte or entry limit
- **THEN** only the necessary oldest entries are discarded, and all surviving entries retain their text, ticks, and order
- **AND** the truncation indicator and saved array representation retain their existing meaning.

#### Scenario: Refused append preserves retained history
- **WHEN** formatting, allocation, or work admission refuses an entry while the log is full
- **THEN** that append changes no retained entry, byte count, or truncation flag
- **AND** a separate host fault diagnostic can still follow the existing diagnostic-retention policy.

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
- **AND** later synchronized dispatch uses fresh invocation state without replaying startup or resetting same-tick budgets; immutable host implementations can be shared.

#### Scenario: Shared host code cannot carry guest state
- **WHEN** callbacks on the same or different computers use the same host helper implementation
- **THEN** mutable bindings, guest functions, ownership tables, errors, and counters remain isolated between invocations
- **AND** rebinding a private local helper in one callback has no effect on a later callback.

#### Scenario: Refused execution does not poison a neighbor
- **WHEN** one callback faults and another computer or Console command subsequently invokes a shared helper
- **THEN** the later invocation uses its own authority, error state, and remaining credits
- **AND** it receives neither the earlier fatal sentinel nor new credits for work already spent on its computer.

## ADDED Requirements

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
