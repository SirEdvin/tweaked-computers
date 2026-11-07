# Program source delta

## MODIFIED Requirements

### Requirement: Ordinary calls to exported functions
Exported functions SHALL be ordinary ephemeral callable values within their own program. Calls SHALL execute synchronously with supplied arguments, preserve native Lua return adjustment and nil arity, and share the current invocation, host-work context, authority and run. Direct calls SHALL NOT enqueue work, create another callback context or synthesize an event argument.

#### Scenario: Call before scheduling the same function
- **WHEN** `start` calls `sample()` and then registers `computer.every(60, "sample")`
- **THEN** the first call executes immediately with no arguments
- **AND** the later timer dispatch invokes the same declared function with its normal TimerEvent in a fresh callback environment.

#### Scenario: Forward references and mutual calls
- **WHEN** one exported function references another exported function declared later in the document
- **THEN** it resolves that function regardless of declaration order
- **AND** direct or mutual recursion follows native Lua behavior without mod call-depth or execution ceilings.

#### Scenario: Function values preserve ordinary call behavior
- **WHEN** a callback captures an exported function in a local variable or temporary table and calls it directly or through `pcall`
- **THEN** the value remains callable and has stable identity within that callback
- **AND** false values, nil holes, zero-return results and multiple returns retain their ordinary native Lua meanings.

#### Scenario: Calling start is not a lifecycle operation
- **WHEN** another function explicitly calls `start(...)`
- **THEN** it executes that function body as an ordinary call with the supplied arguments
- **AND** it does not create a run generation or reset host-work credits, although explicit API effects in that body still occur.

## REMOVED Requirements

### Requirement: Equivalent safety and diagnostics
**Reason**: Trusted native execution withdraws operation-level instrumentation and temporary-value containment, including prepaid regions from reduce-runtime-overhead.
**Migration**: Use Validated native source boundary, Native source diagnostics, and the runtime's stop/host-admission requirements. Keep declaration syntax, export protection, explicit storage, and fresh invocation bindings.

## ADDED Requirements

### Requirement: Validated native source boundary
Both source modes SHALL retain source-size, syntax, name, and host compilation limits. Validation SHALL reject forbidden access before execution. Accepted code SHALL use native operations without injected operation-level guards. Saved or caller-supplied executable text SHALL NOT override validated source.

#### Scenario: Validate without executing
- **WHEN** a candidate uses valid declaration syntax and side-effecting calls inside functions
- **THEN** validation identifies exports without invoking those calls
- **AND** a failed candidate leaves the active run unchanged.

#### Scenario: Native loading follows validation
- **WHEN** validated source reaches invocation
- **THEN** its operations use native Lua, not an interpreter or a second guarded backend
- **AND** source-derived mode and export checks remain authoritative over retained metadata.

#### Scenario: Source limits are not runtime limits
- **WHEN** declarations exceed source bytes, tokens, nodes, nesting, handler names, or a native syntax limit
- **THEN** validation refuses the source without executing it or raising any source allowance
- **AND** accepted bodies have no separate runtime tuple, table-width, recursion, or allocation ceiling.

#### Scenario: Warm and cold validation agree
- **WHEN** identical source and mode have identical settings and remaining host credits
- **THEN** warm and cold validation give equal results and accepted host-charge prefixes
- **AND** caller changes to returned plans cannot modify a private source proof.

### Requirement: Native source diagnostics
Validation SHALL retain original source coordinates. Uncaught native failures SHALL identify the original source line when available, with run and source-revision attribution. Diagnostics SHALL NOT expose host objects, private controls, or generated-source dumps. A missing native column SHALL be reported as column 1, not an invented exact expression position.

#### Scenario: Error in a directly called function
- **WHEN** a timer callback calls another exported function that raises an uncaught error
- **THEN** the diagnostic identifies the failing original source line rather than a private wrapper line
- **AND** attribution still names the active run and source revision.

#### Scenario: Console expression prefix
- **WHEN** an expression-mode Console command fails validation or native execution
- **THEN** the reported position refers to the submitted command, not a synthetic return prefix
- **AND** a native error without a column uses the documented column-1 fallback.

#### Scenario: Non-string failure values
- **WHEN** an invocation throws nil, a table, a function, or an authentic facade
- **THEN** protected calls retain their documented safe value/identity behavior
- **AND** an uncaught diagnostic uses bounded safe text without exposing addresses or traversing arbitrary values.

### Requirement: Fresh invocation bindings without environment caching
Each saved callback SHALL reconstruct fresh function bindings from its active source. Direct calls inside that callback SHALL share its lexical state. Only explicit supported storage SHALL persist between callbacks. Removing execution instrumentation SHALL NOT introduce cached mutable environments or persisted closures.

#### Scenario: Mutated private helper is not durable
- **WHEN** one callback replaces a private lexical function and another callback later runs
- **THEN** the first callback observes its own replacement
- **AND** the next callback reconstructs the original source binding, including after cold load or late joining.

#### Scenario: No source lifecycle change
- **WHEN** new source is saved without applying it while the active run has pending work
- **THEN** dispatch uses the original active source and run identity
- **AND** validation, loading, and reconstruction do not replay startup or earlier device effects.

### Requirement: Trusted execution guidance
The language guide and in-game Reference SHALL describe the trusted execution policy for both modes. They SHALL preserve runnable declaration examples and explain explicit persistence. They SHALL warn about game stalls and memory exhaustion without claiming unrestricted Lua or direct Factorio access.

#### Scenario: Review the language before running code
- **WHEN** a player reads runtime guidance or Console help
- **THEN** the text distinguishes temporary native values from bounded API and retained data
- **AND** it states that Stop cannot interrupt Lua that never returns control to the host.
