# console-shell Specification

## Purpose

Let players experiment with bounded Lua commands and live peripherals inside the computer's Console, using a shared scratch environment without editing or replacing a saved controller program.

## Requirements

### Requirement: Bottom-of-console single-line input
The Console SHALL provide a single-line Lua input at its bottom, Enter submission, and an Execute button. Submission SHALL not require a saved program. The input and controls SHALL remain reachable at supported display sizes and scales, without replacing the existing Console output or other editor tabs.

#### Scenario: Submit a peripheral experiment
- **WHEN** an authorized player pastes `p = peripheral.wrap("tc-42", "red")` into the Console input and presses Enter
- **THEN** that exact line is submitted once for shell execution
- **AND** the saved document, its revision, and the player's source draft remain unchanged.

#### Scenario: Reject unsupported input safely
- **WHEN** input contains a newline or exceeds the published command-byte limit
- **THEN** it is rejected visibly without partial execution or splitting into separate commands
- **AND** the last accepted input draft remains available.

#### Scenario: Empty submission
- **WHEN** an empty or whitespace-only line is submitted
- **THEN** no command or peripheral operation is created.

### Requirement: Shared independent scratch environment
Each computer SHALL have one shell environment shared by its authorized players and isolated from every other computer and from saved-program locals. Shell execution SHALL be available on a valid computer regardless of electrical coverage while its saved program is stopped or running. Ordinary shell assignment SHALL not change explicit application state; explicit API state writes remain real effects.

#### Scenario: Use a previous binding from another player
- **WHEN** player A successfully assigns `p` and player B subsequently submits `print(p.getSize())` on the same computer
- **THEN** B uses the shared binding and both can see the resulting Console output.

#### Scenario: Experiment beside a running controller
- **WHEN** a shell command assigns `counter = 7` while the saved program is running
- **THEN** the shell retains that value without replacing the program or its callbacks, timers, subscriptions, locals, or explicit application state.


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

### Requirement: Native input without command recall
The shell SHALL use native text entry and SHALL NOT retain a navigable command history or intercept Up/Down for command recall. Each viewer's unfinished draft SHALL remain independent. Bounded Console command echoes are output, not replay or history state. This scope was approved after the Factorio 2.0.77 focused-arrow feasibility failure on 2026-10-18.

#### Scenario: Another player's command does not replace a draft
- **WHEN** player A is typing unfinished input while player B submits a line
- **THEN** A's input and native caret remain untouched by output refresh
- **AND** no command-recall cursor or replay record is created.

### Requirement: Durable shell values without saved executable objects
Successful commands SHALL retain bounded scalar values, table graphs with scalar keys, and authentic peripheral bindings or captured peripheral methods as save-safe values. Aliases and cycles within supported table graphs SHALL survive. Persisting user-defined functions, reference-valued table keys, host objects, or mutable library namespaces SHALL fail without publishing an invalid environment.

#### Scenario: Reuse a peripheral after cold reload
- **WHEN** a successful `p = peripheral.wrap(name, "red")` is saved and loaded in a new process
- **THEN** `p` still identifies the same name, generation, and wire
- **AND** using it performs a new live authority check without replaying the original command.

#### Scenario: Preserve table identity
- **WHEN** `a = {}; b = a; a.self = a` succeeds, the game reloads, and `b.value = 9` succeeds
- **THEN** `a.value` is 9 and `a.self == a` remains true.

#### Scenario: Reject unsupported retained functions
- **WHEN** a command attempts to retain a user-defined function in a shell global or reachable table
- **THEN** the shell reports the unsupported retained value and keeps the previous committed environment
- **AND** it never stores a native function in the save or substitutes command replay.

### Requirement: Save and multiplayer continuity without replay
Window closing, save/load, and multiplayer late joining SHALL preserve shell values. Loading SHALL not run command source, repeat peripheral effects, mutate shell state, or renew spent budgets. A joining peer SHALL reconstruct the same authoritative shell state before executing subsequent synchronized commands.

#### Scenario: Close and reopen
- **WHEN** a player closes the computer window and later reopens its Console
- **THEN** previous shell globals remain available.

#### Scenario: Join after a mutation
- **WHEN** a shell command changes a database value and a second client joins afterward
- **THEN** the database write is not repeated
- **AND** both clients use the same retained shell bindings for the next command without desynchronizing.

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

### Requirement: Synchronous experimentation rather than another program runtime
The shell SHALL support synchronous computer metadata/state/logging and peripheral calls. Handler-based timers, event registration, subscription manipulation, and program lifecycle control SHALL be refused from shell commands with an actionable diagnostic. The shell SHALL not register background callbacks or implicitly borrow handlers from the saved program.

#### Scenario: Refuse a handler-dependent operation
- **WHEN** a shell command calls `computer.every(60, "sample")` or a logic peripheral's `subscribe`
- **THEN** it reports that a saved handler program is required
- **AND** no timer, subscription, or program lifecycle mutation occurs.

### Requirement: Command failure isolation
Reported syntax, native runtime, unsupported-value, and host-admission failures SHALL leave the saved program serviceable and report a shell diagnostic. An unsuccessful command SHALL not publish its staged shell environment; earlier completed external API effects and printed output SHALL not be rolled back. Uncaught execution failure SHALL release shell-owned transient outputs without erasing committed shell values.

#### Scenario: Error after a real effect
- **WHEN** a line changes a database value, assigns a scratch variable, and then raises an uncaught error
- **THEN** the database change remains real, the scratch environment remains its previous committed version, and the error is visible
- **AND** the saved controller is neither faulted nor restarted.


### Requirement: Authoritative GUI input routing
Every submission and reset SHALL require the exact opened computer UI, active Console context, current session identity, and current player access. Shell controls SHALL not act on source editing, other tabs, unrelated windows, or gameplay. Delayed execution SHALL recheck access and session generation.

#### Scenario: Reject stale or unauthorized actions
- **WHEN** an event refers to a closed/replaced UI, another player's element, a hidden Console, or a computer the player can no longer access
- **THEN** it causes no command execution, shell reset, or peripheral effect.

### Requirement: Session isolation across physical identities
Shell sessions SHALL belong to the existing placed computer identity and be initialized compatibly for older saves. Mining/replacement, cloning, blueprints, and settings paste SHALL not transfer a shell session to a different computer. Unknown shell schema data SHALL be retained but refused safely, without preventing compatible program execution.

#### Scenario: Clone without copying an experiment
- **WHEN** a computer with shell globals is cloned or mined and placed again
- **THEN** the new computer starts without that shell session
- **AND** the pre-existing source/state transport contract remains unchanged.

#### Scenario: Open an older save
- **WHEN** a computer without shell fields first receives an authorized shell action
- **THEN** an empty compatible session can be created through admitted synchronized work
- **AND** loading alone does not execute source or modify the save graph.

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
- **WHEN** a Console `xpcall` function or error handler encounters fatal host-work refusal
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

### Requirement: Trusted native command language
The shell SHALL accept Lua statements, expressions and shell-global assignments using the trusted native language and approved globals/libraries shared with saved programs, including `print`. Locals SHALL be scoped to one submission. Host globals, dynamic loading, coroutines and overwriting reserved API names SHALL remain forbidden. Console syntax SHALL be independent of the declaration-only saved-program grammar and SHALL NOT relax it.

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

#### Scenario: Console values remain ordinary Lua values
- **WHEN** a Console command evaluates a table expression, assigns a scratch table, or calls an ephemeral local function within the same submission
- **THEN** the existing expression/statement, temporary-table and native-call behavior remains available
- **AND** the unchanged retention validator still rejects executable values in the committed shell graph.

### Requirement: Bounded command boundaries and deterministic ordering
Console input, pending commands, source validation, host API work, retained graphs, and output SHALL retain their existing bounds. Pure Lua execution SHALL be unmetered. Commands SHALL execute once in synchronized non-reentrant order. Fair selection SHALL apply between returning invocations, without retrying commands after execution starts.

#### Scenario: Flood the prompt with finite commands
- **WHEN** players submit more finite commands than the pending queue accepts
- **THEN** existing queue limits refuse additional work without discarding accepted entries or drafts
- **AND** returning commands retain program/Console alternation and neighbor selection.

#### Scenario: Preserve accepted order across a save
- **WHEN** two admitted submissions are pending at a save boundary
- **THEN** each executes at most once in its admitted order after reload, with authority rechecked on every preparation attempt
- **AND** commands invalidated by reset, closed authorization, or removal are canceled visibly rather than executed later with stale authority.

#### Scenario: Native temporary work is distinct from retention
- **WHEN** a finite command creates an oversized temporary value and removes it before successful publication
- **THEN** the former temporary-value ceiling does not reject that computation
- **AND** the complete final scratch graph still must fit its existing byte, node, binding, and value rules.

#### Scenario: Oversized final graph
- **WHEN** a command leaves a value that cannot fit the retained graph
- **THEN** publication fails without changing the previously committed graph
- **AND** earlier completed output and external effects remain, with normal shell-owned cleanup.

#### Scenario: Credits are not renewed by shell lifecycle
- **WHEN** a player closes, reopens, or resets Console after host work has been spent in the same tick
- **THEN** the retained host allowance remains spent, including across cold load
- **AND** scratch reset neither faults the saved program nor permits stale pending commands.

### Requirement: Deferred command preparation
Preparation SHALL defer under the shared pre-execution admission rule without consuming or echoing the command. A preparation prefix that cannot fit full current allowances SHALL fail normally.

#### Scenario: Deferred command preserves committed state and order
- **WHEN** earlier work prevents admission before a Console chunk begins
- **THEN** the command retains its pending identity and FIFO position without echo, effects, or graph publication
- **AND** admitted preparation charges remain spent, including after cold load
- **AND** later execution consumes the command once; any failure after execution starts does not replay it.

### Requirement: Symbolic binding continuity without execution guards
Console SHALL retain authentic facades and captured methods as validated descriptors, never native functions or replayed source. Aliases, cycles, method identity, generation, and selected wire SHALL survive reconstruction. A plain descriptor lookalike SHALL remain ordinary data, not executable authority.

#### Scenario: Captured method identity before first use
- **WHEN** a committed graph contains a facade and repeated aliases of one captured method, then cold-loads
- **THEN** those aliases equal the corresponding facade method before the first method call
- **AND** a separate wrapped facade retains its separate identity.

#### Scenario: Missing or changed target
- **WHEN** a restored binding names a removed device, changed generation, disconnected path, or absent optional method
- **THEN** use fails under the existing typed contract without retargeting or granting authority
- **AND** unrelated committed shell values remain available.

#### Scenario: No executable retention loophole
- **WHEN** a temporary value contains a user closure, built-in function, library namespace, reference-valued key, or forged descriptor
- **THEN** only values accepted by the existing graph contract can commit
- **AND** no removed ownership tracker becomes permission to save executable or foreign objects.
