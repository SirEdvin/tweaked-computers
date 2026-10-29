# Program source delta

## MODIFIED Requirements

### Requirement: Declaration-form saved programs
The system SHALL accept saved documents only when they contain one or more exported `function name(...) ... end` declarations, optional top-level `local function` helpers, comments and empty statements. It SHALL derive the existing API-v1 named-handler inventory from the exported declarations. Declaration names SHALL be unique across the top level and follow the naming rules in `lua-api.md`.

#### Scenario: Run a document without a wrapper
- **WHEN** the player validates, saves and runs a document with exported `start` and `sample` functions
- **THEN** validation succeeds without executing either function
- **AND** activation invokes `start` once and makes both exported names available to the existing named-registration APIs.

#### Scenario: A program has no start function
- **WHEN** a valid document exports another function but not `start`
- **THEN** activation succeeds without choosing or executing an arbitrary function.

#### Scenario: Reject duplicate or reserved declarations
- **WHEN** top-level declarations repeat an identifier, use a protected API/library or forbidden global name, or violate identifier limits
- **THEN** validation rejects the document with an original-source diagnostic.

#### Scenario: Reject a document without any exported function
- **WHEN** a document is empty, contains only comments or empty statements, or defines only private local helpers
- **THEN** validation reports that an exported function is required
- **AND** no active run is created or replaced.

### Requirement: Equivalent safety and diagnostics
Saved programs SHALL retain existing source, compilation, reconstruction, execution, tuple, allocation and depth limits. Declaration discovery, function binding and call paths SHALL remain admitted work. Errors SHALL identify the player's original source location. Fatal quota and stop control SHALL remain unavoidable even through chains of direct or protected calls.

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
The editor starter, in-game Reference and language documentation SHALL teach only function-declaration saved programs and demonstrate one function used both directly and as a named callback. Saved-program functions SHALL NOT be injected into the live Console or its retained value graph.

#### Scenario: Insert and run the starter
- **WHEN** the player inserts the starter into an empty draft and follows Validate, Save, Run
- **THEN** the source uses plain declarations and works through the same compiler and activation path as edited source
- **AND** insertion itself neither saves nor runs the program.

#### Scenario: Console remains separate
- **WHEN** a saved program exports `sample` and a player evaluates that name in Console without a Console binding
- **THEN** it does not resolve to the program function
- **AND** the existing Console rules for ephemeral local functions and forbidden retained user functions remain unchanged.

## REMOVED Requirements

### Requirement: Declaration-only reconstruction boundary
**Reason**: Replaced by `Declaration-only document boundary`, which applies one complete top-level grammar and preserves reconstruction and Data safeguards.
**Migration**: No player-source conversion. Carry the retained initialization/storage scenarios into the replacement and enforce the declaration grammar for all candidates.

### Requirement: Compatible source lifecycle
**Reason**: Replaced by `Function-program source lifecycle`; continuity is specified for supported declaration sources rather than an additional authoring surface.
**Migration**: Preserve supported active source, state, run identity and pending work under the replacement. No converter, automatic source rewrite or new migration is required.

### Requirement: Expanded globals in saved function bodies
**Reason**: Replaced by `Approved globals in saved functions`, retaining the same APIs and output behavior under one saved-program grammar.
**Migration**: Update examples and source-oriented assertions; retain top-level-effect rejection, program printing and the existing `computer.log` contract.

### Requirement: Compatibility of newly reserved source names
**Reason**: Replaced by `Reserved names in saved programs`, with one declaration naming policy and unchanged lexical shadowing and safe reconstruction.
**Migration**: Retain the declaration collision, lexical shadowing and supported-source recovery scenarios in the replacement. No compatibility option or source conversion is introduced.

## ADDED Requirements

### Requirement: Declaration-only document boundary
Saved source SHALL NOT perform top-level calls, variable initialization, ordinary assignments, loops, conditionals, dotted/method declarations or returns. Every top-level statement SHALL satisfy the declaration grammar, not merely one selected portion of the document. Each callback SHALL construct fresh ephemeral functions; durable application values SHALL still require the existing explicit state API.

#### Scenario: Refuse initialization effects
- **WHEN** a document places `sample()`, `local count = 0`, a peripheral lookup or a state write at top level
- **THEN** validation rejects the statement before any guest effect or active-run replacement.

#### Scenario: Refuse a document-level return
- **WHEN** a document contains a top-level return, alone or beside a valid exported function
- **THEN** validation reports an invalid top-level statement at the original source location
- **AND** it neither executes the returned expression nor ignores the statement to accept the remaining declarations.

#### Scenario: Keep executable values out of persistent data
- **WHEN** a callback attempts to store an exported function or private helper in computer state or another Data-only API
- **THEN** the existing data validation refuses it without changing the previous stored value.

#### Scenario: Ordinary function-body values remain supported
- **WHEN** an exported function creates a temporary Lua table, returns it to another function, or passes valid plain data to an existing state or peripheral API
- **THEN** ordinary value, alias, return-adjustment and Data-validation rules remain unchanged
- **AND** the declaration-only restriction applies to the document top level, not to valid function-body expressions.

### Requirement: Function-program source lifecycle
Supported function-declaration programs SHALL use the existing validate/save/activate flow and retain exact active source independently of later edits. Reload SHALL execute no player code, replay no startup, and reset no spent same-tick credits. Accepting the declaration grammar SHALL NOT require rewriting source, resetting explicit data or replacing a compatible active run.

#### Scenario: Preserve a supported running save
- **WHEN** the updated runtime loads a supported save containing an active function-declaration program
- **THEN** its run identity, state, timers and admitted work remain compatible without source rewriting or forced restart.

#### Scenario: Resume the original declaration-form snapshot
- **WHEN** a declaration-form program has pending work, a different source is saved but not applied, and the game is cold-reloaded
- **THEN** the next synchronized dispatch reconstructs the original active functions
- **AND** startup and earlier committed effects are not replayed, while retained work and credits remain intact.

#### Scenario: Invalid replacement retains the active run
- **WHEN** a new declaration-form candidate fails validation
- **THEN** the previous valid run, registrations and explicit state are not replaced.

### Requirement: Approved globals in saved functions
Saved function bodies SHALL resolve the expanded globals according to the runtime API companion. Their availability SHALL NOT permit top-level effects, arbitrary global assignment or borrowing saved-program functions from Console. The editor starter and language reference SHALL demonstrate program `print` while retaining documentation for `computer.log`.

#### Scenario: Print from a saved function
- **WHEN** a valid saved callback calls `print("hello", false, nil)`
- **THEN** validation succeeds and dispatched execution emits the existing bounded program output
- **AND** validation and saving alone emit no output.

#### Scenario: Top-level print remains invalid
- **WHEN** a saved document contains a top-level `print("hello")` outside a function
- **THEN** validation rejects its source shape before activation
- **AND** the previous valid active run and its state are not replaced.

#### Scenario: Teach the ordinary printing path
- **WHEN** the player inserts the starter, then validates, saves and runs it
- **THEN** its initial message uses `print` with multiple arguments and appears once in the Console
- **AND** the example still demonstrates immediate and scheduled calls, while `computer.log(text)` remains available with its existing string-only contract.

### Requirement: Reserved names in saved programs
Top-level exports and private helpers SHALL NOT use any exposed built-in name. Inner lexical locals and parameters SHALL retain ordinary shadowing. A pre-existing active declaration source that collides with a newly reserved name SHALL fault safely on synchronized reconstruction with exact source and application state retained, never rewrite or silently rebind names.

#### Scenario: Reject a new declaration collision
- **WHEN** a declaration document defines top-level `function xpcall()`, `function unpack()` or `local function _VERSION()`
- **THEN** validation rejects the reserved name with an original-source diagnostic
- **AND** a failed replacement leaves the existing active run untouched.

#### Scenario: Genuine lexical shadowing remains legal
- **WHEN** a callback parameter or body-local binding is named `print`, `rawset`, `xpcall`, `unpack` or `_VERSION`
- **THEN** references in that lexical scope use the local value without replacing the global built-in.

#### Scenario: An older declaration source collides after update
- **WHEN** the next synchronized dispatch reconstructs an active source with a formerly permitted top-level name that is now reserved
- **THEN** it reports the reserved-name diagnostic, faults through normal run cleanup and preserves exact source, explicit state and recovery information
- **AND** loading itself executes no player code or source rewrite; the player can rename the declaration and explicitly Save/Run.

#### Scenario: Noncolliding existing source remains compatible
- **WHEN** a supported existing declaration program does not collide with a new built-in
- **THEN** it retains its existing source representation, run identity, explicit state and pending work across reload
- **AND** the global expansion does not force a blanket compiler/storage version rejection or startup replay.

### Requirement: Consistent function-only repository content
Every repository-owned saved-program example and authoring reference SHALL describe or use the declaration grammar exclusively. This includes shipped content, tests, generators, maintained and historical documentation, archived plans, and generated evidence indexes. Unrelated Lua-table values, host modules and runtime metadata SHALL retain their existing meaning.

#### Scenario: Compile the runnable source corpus
- **WHEN** bundled examples, Reference tutorials, planning examples and behavioral fixture sources are checked through the saved-program compiler
- **THEN** runnable cases compile as declaration programs and retain their functional assertions
- **AND** deliberately invalid cases exercise the documented grammar and safeguards without preserving a second authoring surface.

#### Scenario: Check the whole checkout and generated package
- **WHEN** repository content and a freshly built package are audited after regenerating derived documentation and evidence indexes
- **THEN** saved-program language descriptions, complete examples, comments and relevant names consistently describe the accepted grammar
- **AND** historical checkout documents and hidden generated claim metadata receive the same review as maintained documentation.

#### Scenario: Preserve independent history and evidence
- **WHEN** historical checkout prose or examples are cleaned up
- **THEN** no Git history, published release asset, external frozen receipt or player save is rewritten
- **AND** the updated checkout does not claim that a changed example or workload was executed by an earlier verification run.
