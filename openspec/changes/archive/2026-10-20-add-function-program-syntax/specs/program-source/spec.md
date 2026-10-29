# Program Source

## Purpose

Let players author saved computer programs as named functions as named function declarations, while preserving bounded native execution, ordinary intra-program calls.

## ADDED Requirements

### Requirement: Declaration-form saved programs
The system SHALL accept declaration-form documents containing one or more exported `function name(...) ... end` declarations, optional top-level `local function` helpers, comments and empty statements. It SHALL derive the existing API-v1 named-handler inventory without requiring a returned table. Declaration names SHALL be unique across the top level and follow the naming rules in `lua-api.md`.

#### Scenario: Run a document without a wrapper
- **WHEN** the player validates, saves and runs a declaration-form document with `start` and `sample`
- **THEN** validation succeeds without executing either function
- **AND** activation invokes `start` once and makes both exported names available to the existing named-registration APIs.

#### Scenario: A program has no start function
- **WHEN** a valid document exports another function but not `start`
- **THEN** activation succeeds without choosing or executing an arbitrary function.

#### Scenario: Reject duplicate or reserved declarations
- **WHEN** top-level declarations repeat an identifier, use a protected API/library or forbidden global name, or violate identifier limits
- **THEN** validation rejects the document with an original-source diagnostic.

#### Scenario: Reject a document without any exported function
- **WHEN** a document is empty, contains only comments, or defines only private local helpers
- **THEN** declaration-form validation reports that an exported function is required
- **AND** no active run is created or replaced.

### Requirement: Ordinary calls to exported functions
Exported functions SHALL be ordinary ephemeral callable values within their own program. Calls SHALL execute synchronously with supplied arguments, preserve bounded Lua return adjustment and nil arity, and share the current callback's guard, budget, authority and run. Direct calls SHALL NOT enqueue work, create another callback context or synthesize an event argument.

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

### Requirement: Private lexical helpers and protected exports
Top-level `local function` declarations SHALL remain private helpers with normal lexical scope, self-recursion and declaration-order visibility. Lexical parameters and locals SHALL shadow exported names normally. Exported bindings SHALL NOT be reassignable by guest code, and ordinary global assignment SHALL remain forbidden.

#### Scenario: Share a private helper
- **WHEN** a local helper is declared before exported functions that reference it
- **THEN** those functions can call the helper
- **AND** the helper is absent from the registerable handler inventory.

#### Scenario: A later local helper is not implicitly hoisted
- **WHEN** an exported function references a private helper whose lexical declaration follows that function
- **THEN** validation rejects the unresolved name rather than treating it as an exported or host global.

#### Scenario: A parameter shadows an exported name
- **WHEN** a function parameter or local has the same name as an export
- **THEN** references and assignments in that lexical scope use the local binding without changing the exported function.

#### Scenario: Reject replacement of a public binding
- **WHEN** a function attempts to assign to an unshadowed exported name, redefine it from inside a callback, or write another global
- **THEN** validation rejects the write before activation.

### Requirement: Explicit named event registration
Automatic export SHALL only populate the declared handler inventory. Except for the existing `start` activation rule, functions SHALL execute as callbacks only through existing explicit registrations, subscriptions or timers. Those APIs SHALL continue to accept exported names as strings, never function values or private helper names.

#### Scenario: Event-like names do not auto-subscribe
- **WHEN** a document declares `monitor_touch` but never registers it
- **THEN** monitor touches do not invoke that function merely because its name matches an event.

#### Scenario: Register a name rather than a value
- **WHEN** a callback registers `"sample"` for a declared exported function
- **THEN** the registration succeeds under existing API validation
- **AND** supplying the function value, an undeclared name, a local helper name or a nested function name fails with the existing argument diagnostic.

### Requirement: Declaration-only reconstruction boundary
Declaration-form source SHALL NOT perform top-level calls, variable initialization, ordinary assignments, loops, conditionals, dotted/method declarations or returns. Every top-level statement must satisfy the declaration grammar. Each callback SHALL construct fresh ephemeral functions; durable application values SHALL still require the existing explicit state API.

#### Scenario: Refuse initialization effects
- **WHEN** a document places `sample()`, `local count = 0`, a peripheral lookup or a state write at top level
- **THEN** validation rejects the statement before any guest effect or active-run replacement.

#### Scenario: Keep executable values out of persistent data
- **WHEN** a callback attempts to store an exported function or private helper in computer state or another Data-only API
- **THEN** the existing data validation refuses it without changing the previous stored value.

### Requirement: Equivalent safety and diagnostics
Saved declarations SHALL retain existing source, compilation, reconstruction, execution, tuple, allocation and depth limits. New declaration discovery, function binding and call paths SHALL be admitted work. Errors SHALL identify the player's original source location. Fatal quota and stop control SHALL remain unavoidable even through chains of direct or protected calls.

#### Scenario: Recursion cannot renew or swallow a budget
- **WHEN** exported functions call each other indefinitely inside `pcall`
- **THEN** the current run faults within its existing limits
- **AND** the protected call cannot continue to another peripheral effect or obtain fresh credits.

#### Scenario: Error in a directly called function
- **WHEN** a timer callback directly calls another function that raises an uncaught error
- **THEN** the diagnostic points into that function's original source rather than a generated wrapper
- **AND** run, revision and dispatched-handler attribution retain the existing lifecycle meaning.

#### Scenario: Bounded declaration inventories
- **WHEN** exported declarations exceed the handler-name limit, or private helpers exceed source/compiler/native syntax limits
- **THEN** validation rejects the source without raising production limits or changing the active program
- **AND** the maximum exported inventory fits when all other limits are satisfied.

#### Scenario: Warm and cold proofs spend equally
- **WHEN** the same declaration-form source is validated or reconstructed with identical remaining credits using a warm or cold compiler cache
- **THEN** success, refusal and accepted charge prefixes agree
- **AND** mutated caller-owned generated text or handler inventories never become trusted executable input.

### Requirement: Discoverable authoring without Console coupling
The editor starter and primary language reference SHALL teach declaration-form programs and demonstrate one function used both directly and as a named callback. Saved-program functions SHALL NOT be injected into the live Console or its retained value graph.

#### Scenario: Insert and run the starter
- **WHEN** the player inserts the starter into an empty draft and follows Validate, Save, Run
- **THEN** the source uses plain declarations and works through the same compiler and activation path as edited source
- **AND** insertion itself neither saves nor runs the program.

#### Scenario: Console remains separate
- **WHEN** a saved program exports `sample` and a player evaluates that name in Console without a Console binding
- **THEN** it does not resolve to the program function
- **AND** the existing Console rules for ephemeral local functions and forbidden retained user functions remain unchanged.
