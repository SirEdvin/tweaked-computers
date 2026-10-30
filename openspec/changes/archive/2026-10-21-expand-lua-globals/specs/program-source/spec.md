# Program source spec delta

## ADDED Requirements

### Requirement: Expanded globals in saved function bodies
Saved-function callbacks SHALL resolve the expanded globals according to the [runtime companion](../computer-runtime/lua-api.md). Their availability SHALL NOT permit top-level effects, arbitrary global assignment or borrowing saved-program functions from Console. The editor starter and language reference SHALL demonstrate program `print` while retaining documentation for `computer.log`.

#### Scenario: Print from a saved function
- **WHEN** a valid saved-function callback calls `print("hello", false, nil)`
- **THEN** validation succeeds and dispatched execution emits the same bounded program output
- **AND** validation and saving alone emit no output.

#### Scenario: Top-level print remains invalid
- **WHEN** a saved document contains a top-level `print("hello")` outside a function
- **THEN** validation rejects its source shape before activation
- **AND** the previous valid active run and its state are not replaced.

#### Scenario: Teach the ordinary printing path
- **WHEN** the player inserts the starter, then validates, saves and runs it
- **THEN** its initial message uses `print` with multiple arguments and appears once in the Console
- **AND** the example still demonstrates immediate and scheduled calls, while `computer.log(text)` remains available with its existing string-only contract.

### Requirement: Compatibility of newly reserved source names
Declaration-form top-level exports and private helpers SHALL NOT use any newly exposed built-in name. Inner lexical locals and parameters SHALL retain ordinary shadowing. A pre-existing active declaration source that now collides SHALL fault safely on synchronized reconstruction with exact source and application state retained, never rewrite or silently rebind names.

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
