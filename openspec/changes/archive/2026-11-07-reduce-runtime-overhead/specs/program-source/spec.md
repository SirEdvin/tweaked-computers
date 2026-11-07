# Spec Delta

## MODIFIED Requirements

### Requirement: Equivalent safety and diagnostics
Saved programs SHALL retain existing source, compilation, reconstruction, execution, tuple, allocation and depth limits. Declaration discovery, function binding and call paths SHALL remain admitted work under the revised accounting contract. Fewer work checkpoints SHALL NOT permit unpaid execution or unbounded work between checks. Errors SHALL identify the player's original source location. Fatal quota and stop control SHALL remain unavoidable even through chains of direct or protected calls.

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

#### Scenario: A prepaid region cannot bypass a loop or call boundary
- **WHEN** the compiler combines checks for a finite straight-line region
- **THEN** work is admitted before that region executes, and every repeatable loop path and recursive call remains bounded
- **AND** control flow cannot enter the region after its admission check or spend the same reserved credit twice.

#### Scenario: Dynamic work still needs its own admission
- **WHEN** a prepaid region reaches formatting, copying, string comparison, allocation, a guest call, or a host effect
- **THEN** the operation's actual bounded cost and required ownership checks are admitted before that work or effect
- **AND** a static region allowance does not authorize an unknown-size operation or weaken tuple and depth limits.

#### Scenario: Fatal control ends a region before later effects
- **WHEN** a protected call encounters fatal exhaustion or saved-program stop within a compiled region
- **THEN** later operations in that region do not execute
- **AND** neither its error handler nor another protected call receives the private fatal value.

#### Scenario: Changed checkpoint retains useful source diagnostics
- **WHEN** revised admission refuses a compiled region
- **THEN** the diagnostic identifies that region's original source boundary and current handler attribution
- **AND** ordinary runtime errors retain their original source locations rather than generated-wrapper coordinates.
