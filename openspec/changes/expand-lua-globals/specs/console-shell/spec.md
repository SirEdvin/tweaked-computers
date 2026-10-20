# Console shell spec delta

## MODIFIED Requirements

### Requirement: Guarded native command language
The shell SHALL accept Lua statements, expressions, and shell-global assignments without a handler descriptor, using the existing bounded native language and the approved globals/libraries shared with saved programs, including `print`. Locals SHALL be scoped to one submission. Host globals, dynamic loading, coroutines, unguarded execution, and overwriting reserved API names SHALL remain forbidden. Saved-program syntax SHALL remain unchanged.

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

## ADDED Requirements

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
- **WHEN** a Console `xpcall` function or error handler exceeds a fatal bound
- **THEN** the command cannot publish its staged environment or continue effects through another handler
- **AND** the saved program remains serviceable, prior committed shell values survive, and normal shell-owned resource cleanup applies.

### Requirement: Reserved-name collisions retain old scratch data
If a previously committed shell root contains a newly reserved built-in name, subsequent evaluation SHALL fail before guest execution with an actionable `E_UNSUPPORTED` diagnostic naming the collision. It SHALL NOT hide, delete or reinterpret the stored binding. Loading alone SHALL leave the graph unchanged. The existing confirmed Reset Shell action SHALL remain available; a collision SHALL NOT fault or reset the saved program.

#### Scenario: An older shell used a new API name as data
- **WHEN** a retained root containing `rawset = 5` or `_VERSION = "custom"` is opened after the API expansion and a command is evaluated
- **THEN** evaluation reports the reserved-name collision and explains that Reset Shell discards the scratch environment
- **AND** the old graph, application state, source and saved program are retained without command effects or automatic reset.

#### Scenario: Nested keys are not global collisions
- **WHEN** an otherwise valid shell graph contains a nested table field named `rawget`, `xpcall` or `_VERSION` but no colliding root binding
- **THEN** it remains usable and retains that field normally.

#### Scenario: Reset is explicit and limited to the shell
- **WHEN** the user confirms the existing Reset Shell action after a collision
- **THEN** the colliding scratch environment is cleared through the normal reset lifecycle
- **AND** subsequent commands can use the new built-ins without changing the saved program, application state or historical Console output.
