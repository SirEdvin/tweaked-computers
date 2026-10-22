## MODIFIED Requirements

### Requirement: Ordinary calls to exported functions
Exported functions SHALL be ordinary invocation-scoped callable values within their own program. Calls SHALL remain sequential from the caller perspective, including across host scheduling suspension, with supplied arguments, preserve bounded Lua return adjustment and nil arity, and share the current callback's guard, budget, authority and run. Direct calls SHALL NOT enqueue work, create another callback context or synthesize an event argument.

#### Scenario: Call before scheduling the same function
- **WHEN** `start` calls `sample()` and then registers `computer.every(60, "sample")`
- **THEN** the first call executes immediately with no arguments
- **AND** the later timer dispatch invokes the same declared function with its normal TimerEvent in a fresh callback environment.

#### Scenario: Forward references and mutual calls
- **WHEN** one exported function references another exported function declared later in the document
- **THEN** it resolves that function regardless of declaration order
- **AND** direct or mutual recursion remains subject to the existing call-depth and work ceilings.

#### Scenario: Function values preserve ordinary call behavior
- **WHEN** a callback captures an exported function in a local variable or temporary table and calls it directly or through `pcall`
- **THEN** the value remains callable and has stable identity within that callback
- **AND** false values, nil holes, zero-return results and multiple returns retain their ordinary bounded Lua meanings.

#### Scenario: Calling start is not a lifecycle operation
- **WHEN** another function explicitly calls `start(...)`
- **THEN** it executes that function body as an ordinary call with the supplied arguments
- **AND** it does not create a run generation or reset budgets, although explicit API effects in that body still occur.

### Requirement: Declaration-only reconstruction boundary
Declaration-form source SHALL NOT perform top-level calls, variable initialization, ordinary assignments, loops, conditionals, dotted/method declarations or returns. Mixing declarations with a returned descriptor SHALL be rejected. Each new callback SHALL begin with fresh lexical environments. A suspended callback SHALL preserve its private environments until completion; durable application values between callbacks SHALL still require explicit state.

#### Scenario: Refuse initialization effects
- **WHEN** a document places `sample()`, `local count = 0`, a peripheral lookup or a state write at top level
- **THEN** validation rejects the statement before any guest effect or active-run replacement.

#### Scenario: Refuse mixed formats
- **WHEN** a document defines a top-level function and also returns a descriptor
- **THEN** validation reports an incompatible document shape rather than choosing a format or silently ignoring part of the source.

#### Scenario: Keep executable values out of persistent data
- **WHEN** a callback attempts to store an exported function or private helper in computer state or another Data-only API
- **THEN** the existing data validation refuses it without changing the previous stored value.

### Requirement: Equivalent safety and diagnostics
Both source forms SHALL obey configurable resource-policy rather than arbitrary source/token/handler/tuple ceilings. New declaration discovery, function binding and call paths SHALL be admitted work. Errors SHALL identify the player's original source location. Scheduling suspension and stop control SHALL remain unavoidable even through chains of direct or protected calls.

#### Scenario: Recursion cannot renew or swallow a budget
- **WHEN** exported functions call each other indefinitely inside `pcall`
- **THEN** work exhaustion suspends the invocation; depth or retained-memory exhaustion refuses recoverably
- **AND** protected calls cannot swallow suspension or obtain fresh same-tick credits, but can recover from capacity errors.

#### Scenario: Error in a directly called function
- **WHEN** a timer callback directly calls another function that raises an uncaught error
- **THEN** the diagnostic points into that function's original source rather than a generated wrapper
- **AND** run, revision and dispatched-handler attribution retain the existing lifecycle meaning.

#### Scenario: Bounded declaration inventories
- **WHEN** exported declarations exceed the old handler-name limit while fitting configured resources and supported native syntax
- **THEN** validation accepts the source without a separate handler-count ceiling or changing the active program
- **AND** native syntax restrictions and recoverable memory/depth protections remain explicit.

#### Scenario: Warm and cold proofs spend equally
- **WHEN** the same declaration-form source is validated or reconstructed with identical remaining credits using a warm or cold compiler cache
- **THEN** success, refusal and accepted charge prefixes agree
- **AND** mutated caller-owned generated text or handler inventories never become trusted executable input.
