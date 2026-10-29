# console-shell delta

## MODIFIED Requirements

### Requirement: Shared independent scratch environment
Each computer SHALL have one shell environment shared by its authorized players and isolated from every other computer and from saved-program locals. Shell execution SHALL be available on a valid computer regardless of electrical coverage while its saved program is stopped or running. Ordinary shell assignment SHALL not change explicit application state; explicit API state writes remain real effects.

#### Scenario: Use a previous binding from another player
- **WHEN** player A successfully assigns `p` and player B subsequently submits `print(p.getSize())` on the same computer
- **THEN** B uses the shared binding and both can see the resulting Console output.

#### Scenario: Experiment beside a running controller
- **WHEN** a shell command assigns `counter = 7` while the saved program is running
- **THEN** the shell retains that value without replacing the program or its callbacks, timers, subscriptions, locals, or explicit application state.

### Requirement: Explicit shell lifecycle and reset
Successful Run/Apply, explicit computer Stop, and confirmed Reset Shell SHALL clear shell values, cancel pending commands, and release shell-owned transient resources. Failed activation, window closing, automatic program faults, and electrical supply changes SHALL not discard the committed shell environment. Reset Shell SHALL not stop the saved program or reset its explicit state.

#### Scenario: Restart the computer
- **WHEN** a new saved program activation succeeds
- **THEN** subsequent shell commands use an empty new shell session
- **AND** a rejected activation leaves the prior shell session intact.

#### Scenario: Reset only the sandbox
- **WHEN** an authorized player confirms Reset Shell
- **THEN** every viewer observes the reset session and pending old-session submissions cannot execute
- **AND** the saved program, editor drafts, explicit application state, KV contents, and monitor contents are not erased.

#### Scenario: Power interruption
- **WHEN** electrical supply around the computer disappears and returns
- **THEN** committed shell values, queued commands and valid shell-owned output remain unaffected
- **AND** pending submissions execute at most once under normal scheduling, not through a restoration replay.

### Requirement: Live effects with independent ownership
Shell peripheral calls SHALL use the existing real service contracts and live force, surface, wire, generation, and native radar/speaker power checks; custom-device services require no electricity. Shell-owned logic output and monitor synchronization selection SHALL be distinguishable from program-owned resources. Existing shared-write ordering and exclusivity rules SHALL apply, without granting a shell privileged access.

#### Scenario: Detect a stale wrapper
- **WHEN** a wrapped peripheral is disconnected, replaced, or regrouped before the next command
- **THEN** the retained wrapper fails safely rather than retargeting by label or position.

#### Scenario: Shell failure does not clear a later program write
- **WHEN** a shell writes a logic output, the saved program later takes ownership, and the shell then fails or resets
- **THEN** shell cleanup does not clear the program-owned output.

#### Scenario: Respect monitor selection ownership
- **WHEN** a shell attempts to select a monitor already exclusively selected by the running program
- **THEN** the existing ownership-conflict error is reported and the program's selection remains unchanged.

### Requirement: Shared bounded admission and deterministic ordering
Shell input, retained values, pending submissions, compilation, execution, serialization, and output SHALL have explicit limits. Shell work SHALL share existing per-computer and aggregate tick credits with the saved program. Commands SHALL execute non-reentrantly in synchronized order, with bounded fair service and no automatic retry after execution starts.

#### Scenario: Flood the prompt while a controller runs
- **WHEN** players submit multiple commands and a command contains an infinite loop
- **THEN** pending admission is bounded, the loop is terminated by guarded work limits, and an unrelated computer remains serviceable
- **AND** GUI close/reopen, reset, or repeated submission cannot renew same-tick credits.

#### Scenario: Preserve accepted order across a save
- **WHEN** two admitted submissions are pending at a save boundary
- **THEN** each is considered at most once in its admitted order after reload, with execution-time authority rechecked
- **AND** commands invalidated by reset, closed authorization, or removal are canceled visibly rather than executed later with stale authority.

## ADDED Requirements

### Requirement: Runnable-only Console service
Admitting a Console command SHALL wake that computer through existing shared scheduling. A computer with no queued program event or Console submission SHALL receive no dispatch visit. Open Console viewers may request bounded UI refresh without manufacturing executable work or renewing shared credits.

#### Scenario: Console on an otherwise idle computer
- **WHEN** a player submits a command to a valid stopped computer outside electrical coverage
- **THEN** the command becomes runnable, executes once and leaves execution membership after its queue drains.

#### Scenario: Viewer is not execution demand
- **WHEN** a player leaves an unchanged Console window open without submitting commands
- **THEN** only the open-session refresh policy remains eligible; no empty callback or repeated shell dispatch occurs.

#### Scenario: UI closes or authorization changes
- **WHEN** a viewer closes or loses access to its session
- **THEN** its UI refresh membership is removed and pending commands follow existing authorization/cancellation rules without affecting another valid viewer.
