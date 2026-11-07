# Console shell delta

## MODIFIED Requirements

### Requirement: Command failure isolation
Reported syntax, native runtime, unsupported-value, and host-admission failures SHALL leave the saved program serviceable and report a shell diagnostic. An unsuccessful command SHALL not publish its staged shell environment; earlier completed external API effects and printed output SHALL not be rolled back. Uncaught execution failure SHALL release shell-owned transient outputs without erasing committed shell values.

#### Scenario: Error after a real effect
- **WHEN** a line changes a database value, assigns a scratch variable, and then raises an uncaught error
- **THEN** the database change remains real, the scratch environment remains its previous committed version, and the error is visible
- **AND** the saved controller is neither faulted nor restarted.

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

## REMOVED Requirements

### Requirement: Guarded native command language
**Reason**: Console commands use the same trusted native execution policy as saved programs.
**Migration**: Use Trusted native command language. Keep the approved names, source grammar, global-name protection, and persistence rules.

### Requirement: Shared bounded admission and deterministic ordering
**Reason**: Execution and temporary values no longer consume per-computer guest quotas. Source, API, queue, output, and retained graph bounds remain.
**Migration**: Use Bounded command boundaries and deterministic ordering. Never treat its host limits as an infinite-loop watchdog.

## ADDED Requirements

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
