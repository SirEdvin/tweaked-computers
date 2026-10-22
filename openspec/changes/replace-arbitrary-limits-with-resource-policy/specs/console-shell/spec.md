## MODIFIED Requirements

### Requirement: Bottom-of-console single-line input
The Console SHALL provide a single-line Lua input at its bottom, Enter submission, and an Execute button. Submission SHALL not require a saved program. The input and controls SHALL remain reachable at supported display sizes and scales, without replacing the existing Console output or other editor tabs.

#### Scenario: Submit a peripheral experiment
- **WHEN** an authorized player pastes `p = peripheral.wrap("tc-42", "red")` into the Console input and presses Enter
- **THEN** that exact line is submitted once for shell execution
- **AND** the saved document, its revision, and the player's source draft remain unchanged.

#### Scenario: Reject unsupported input safely
- **WHEN** input contains a newline or cannot be admitted within configured pending-storage capacity
- **THEN** it is rejected visibly without partial execution or splitting into separate commands
- **AND** the last accepted input draft remains available.

#### Scenario: Empty submission
- **WHEN** an empty or whitespace-only line is submitted
- **THEN** no command or peripheral operation is created.

### Requirement: Guarded native command language
The shell SHALL accept Lua statements, expressions, and shell-global assignments without a handler descriptor, using the supported language with resource-policy continuation execution and the approved globals/libraries shared with saved programs, including `print`. Locals SHALL be scoped to one submission. Host globals, dynamic loading, coroutines, unguarded execution, and overwriting reserved API names SHALL remain forbidden. Saved-program syntax SHALL remain unchanged.

#### Scenario: Globals survive and locals do not
- **WHEN** `x = 5; local y = 6` succeeds and the next line is `print(x, y)`
- **THEN** output represents `5` and `nil`.

#### Scenario: Preserve the saved-program trust boundary
- **WHEN** a shell command accesses `_G`, `_ENV`, `game`, or attempts to replace `peripheral`
- **THEN** it fails with a shell diagnostic and no host access is granted
- **AND** existing saved-program validation still rejects shell-only syntax.

#### Scenario: Use expanded base globals interactively
- **WHEN** a Console command uses `xpcall`, `rawequal`, `rawget`, `rawset`, `rawlen`, `unpack` or `_VERSION`
- **THEN** it follows the same base-global contract as saved programs
- **AND** successful print calls and displayed expression results keep their existing command attribution, ordering and no-duplicate-output rules.

#### Scenario: Expanded built-ins cannot be replaced
- **WHEN** a command assigns to any added built-in global, including `_VERSION`, rather than a genuine lexical local
- **THEN** compilation rejects the write before execution
- **AND** ordinary local/parameter shadowing remains allowed without modifying the built-in.

### Requirement: Visible ordered results and diagnostics
Submitted commands, printed output, expression return values, and shell errors SHALL appear in the bounded selectable Console in execution order and be distinguishable from program diagnostics. `print(...)` SHALL preserve nil/false positions and return no values. Zero-result expressions SHALL not display a fabricated nil. Follow-off SHALL keep the single Console text box live without automatic scrolling, preserving the reader's viewport rather than freezing output. Incoming changed text MAY clear native selection; native selection/copy SHALL work between updates and unchanged text SHALL NOT be reassigned. Follow-on SHALL resume tailing, without a separate snapshot view, per-entry widgets or Refresh action. Output retention SHALL use configurable resource-policy with visible truncation; discarded bytes SHALL NOT be recovered or unrelated bytes reselected.

#### Scenario: Print a tuple without duplicate output
- **WHEN** `print(false, nil, 3)` executes
- **THEN** one print entry displays those three values in order
- **AND** no extra expression-result entry is emitted for the print call.

#### Scenario: Display values and recover from syntax failure
- **WHEN** a player submits `false`, `nil`, an invalid line, and then `2 + 3`
- **THEN** the Console distinguishes false, one nil result, a source-located shell error, and the numeric result of the final expression
- **AND** syntax failure does not prevent later commands.

### Requirement: Save and multiplayer continuity without replay
Window closing, save/load, and multiplayer late joining SHALL preserve committed shell values and exact unfinished-command progress, including its staged environment. Loading SHALL not run command source, repeat peripheral effects, mutate shell state, or renew spent budgets. A joining peer SHALL reconstruct the same authoritative shell state before executing subsequent synchronized commands.

#### Scenario: Close and reopen
- **WHEN** a player closes the computer window and later reopens its Console
- **THEN** previous shell globals remain available.

#### Scenario: Join after a mutation
- **WHEN** a shell command changes a database value and a second client joins afterward
- **THEN** the database write is not repeated
- **AND** both clients use the same retained shell bindings for the next command without desynchronizing.

### Requirement: Command failure isolation
Syntax, runtime, unsupported-value, and hard-resource failures SHALL leave the saved program serviceable and report a shell diagnostic. An unsuccessful command SHALL not publish its staged shell environment; earlier completed external API effects and printed output SHALL not be rolled back. Uncaught ordinary execution failure SHALL release shell-owned transient outputs without erasing committed shell values. A hard-resource refusal SHALL end only the command with its committed shell graph and outputs retained. Work exhaustion SHALL preserve and resume the command rather than fail it.

#### Scenario: Error after a real effect
- **WHEN** a line changes a database value, assigns a scratch variable, and then raises an uncaught error
- **THEN** the database change remains real, the scratch environment remains its previous committed version, and the error is visible
- **AND** the saved controller is neither faulted nor restarted.

### Requirement: Shared bounded admission and deterministic ordering
Shell input, retained values, pending submissions, compilation, execution, serialization and output SHALL obey configurable resource-policy without independent source, binding or session counts. Shell work SHALL share existing per-computer and aggregate tick credits with the saved program. Commands SHALL execute non-reentrantly in synchronized order, with bounded fair service and continuation resumption rather than replay after execution starts.

#### Scenario: Flood the prompt while a controller runs
- **WHEN** players submit multiple commands and a command contains an infinite loop
- **THEN** pending admission is bounded, the loop is sliced by guarded work budgets and can be explicitly canceled, and an unrelated computer remains serviceable
- **AND** GUI close/reopen, reset, or repeated submission cannot renew same-tick credits.

#### Scenario: Preserve accepted order across a save
- **WHEN** two admitted submissions are pending at a save boundary
- **THEN** each is considered at most once in its admitted order after reload, with execution-time authority rechecked
- **AND** commands invalidated by reset, closed authorization or removal are canceled visibly; power loss pauses an already-started continuation until authority is revalidated, never replays it.

### Requirement: New helpers preserve shell retention boundaries
Successful commands using the expanded globals SHALL retain only values already supported by the shell graph contract. Raw mutation SHALL preserve supported aliases and cycles without granting private access. Built-in functions, user closures, library namespaces and reference-valued keys SHALL remain forbidden as retained values. A failed command SHALL leave the previous committed graph intact while retaining earlier completed output and external effects.

#### Scenario: Raw mutation survives a later command and reload
- **WHEN** `a = {}; b = a; rawset(a, "self", a); rawset(a, "value", false)` succeeds and the shell is cold-reloaded
- **THEN** a subsequent command observes `rawequal(a, b)`, `rawequal(rawget(a, "self"), a)` and a false value
- **AND** no command is replayed to reconstruct the aliases.

#### Scenario: Capturing a new built-in does not persist executable state
- **WHEN** a command assigns `saved = rawset` or stores `xpcall` in a retained table
- **THEN** retention is refused with the existing unsupported-value diagnostic
- **AND** the previous committed shell graph remains unchanged; local use within a submission remains valid.

#### Scenario: Fatal protected execution isolates the saved program
- **WHEN** a Console `xpcall` function or error handler encounters work suspension or hard-resource refusal
- **THEN** suspension retains its staged environment without publishing it; a caught hard-resource error can recover, and an uncaught one ends only the command
- **AND** the saved program remains serviceable, prior committed shell values survive, and suspension/resource refusal does not clear otherwise valid shell-owned output.

## ADDED Requirements

### Requirement: Non-lossy command backpressure
A full pending-command allowance SHALL visibly refuse a new submission before acceptance and preserve its editable input. It SHALL NOT drop an accepted command as if it were an event. An unfinished command SHALL retain its staging graph and lexical values across budget pauses and cold reload.

#### Scenario: Save during a command with effects
- **WHEN** a command has printed once, written a peripheral once and is suspended inside a loop
- **THEN** reload resumes that loop without repeating the print or write, commits shell values only on success and continues sharing fair service with the saved program.
