# Spec Delta

## MODIFIED Requirements

### Requirement: Visible ordered results and diagnostics
Submitted commands, printed output, expression return values, and shell errors SHALL appear in the bounded selectable Console in execution order and be distinguishable from program diagnostics. Print and log output SHALL use the admitted command owner and preserve the same bounded retention contract as program output.

#### Scenario: Console values and live Follow behavior
- **WHEN** commands and output are displayed or Follow changes
- **THEN** `print(...)` SHALL preserve nil/false positions and return no values. Zero-result expressions SHALL not display a fabricated nil. Follow-off SHALL keep the single Console text box live without automatic scrolling, preserving the reader's viewport rather than freezing output. Incoming changed text MAY clear native selection; native selection/copy SHALL work between updates and unchanged text SHALL NOT be reassigned. Follow-on SHALL resume tailing, without a separate snapshot view, per-entry widgets or Refresh action. Existing output bounds and visible truncation SHALL remain unchanged; discarded bytes SHALL NOT be recovered or unrelated bytes reselected.

#### Scenario: Print a tuple without duplicate output
- **WHEN** `print(false, nil, 3)` executes
- **THEN** one print entry displays those three values in order
- **AND** no extra expression-result entry is emitted for the print call.

#### Scenario: Display values and recover from syntax failure
- **WHEN** a player submits `false`, `nil`, an invalid line, and then `2 + 3`
- **THEN** the Console distinguishes false, one nil result, a source-located shell error, and the numeric result of the final expression
- **AND** syntax failure does not prevent later commands.

#### Scenario: Local output retains command attribution
- **WHEN** a command calls print and computer.log through the private local-output route
- **THEN** each successful call appends exactly one entry with its existing shell attribution and no return values
- **AND** all attribution bytes count toward the existing output bound before publication or eviction.

#### Scenario: Refused output cannot evict earlier entries
- **WHEN** a command's next entry exceeds a byte bound or lacks work or allocation credit
- **THEN** that entry causes no partial append, history eviction, or truncation-flag change
- **AND** earlier successful output remains committed, subject to ordinary retention by later output or host diagnostics.

#### Scenario: Log argument compatibility is unchanged
- **WHEN** computer.log receives extra arguments in a command or saved callback
- **THEN** the Console override retains its documented ignored-extra-argument exception
- **AND** the saved callback retains exact one-argument validation; both routes still require string text.

### Requirement: Shared bounded admission and deterministic ordering
Shell input, retained values, pending submissions, compilation, execution, serialization, and output SHALL have explicit limits. Shell work SHALL share existing per-computer and aggregate tick credits with the saved program under the revised accounting contract. Internal charge changes SHALL NOT increase these ceilings or renew spent credit. Commands SHALL execute non-reentrantly in synchronized order, with bounded fair service and no automatic retry after execution starts.

#### Scenario: Flood the prompt while a controller runs
- **WHEN** players submit multiple commands and a command contains an infinite loop
- **THEN** pending admission is bounded, the loop is terminated by guarded work limits, and an unrelated computer remains serviceable
- **AND** GUI close/reopen, reset, or repeated submission cannot renew same-tick credits.

#### Scenario: Preserve accepted order across a save
- **WHEN** two admitted submissions are pending at a save boundary
- **THEN** each is considered at most once in its admitted order after reload, with execution-time authority rechecked
- **AND** commands invalidated by reset, closed authorization, or removal are canceled visibly rather than executed later with stale authority.

#### Scenario: Warm helpers do not grant a cheaper command
- **WHEN** identical commands execute with identical retained shell values, live world state, settings, and remaining credits
- **THEN** warm and cold host caches produce identical admission, paid prefixes, and output
- **AND** helper reuse does not share a previous command's mutable guard or bypass current player/session authorization.

#### Scenario: Budget failure follows a completed command effect
- **WHEN** revised accounting permits a command's first output or peripheral effect and refuses a later operation
- **THEN** the completed effect remains, the refused effect does not occur, and the staged shell graph is not published
- **AND** the saved program remains serviceable under its remaining shared credits.
