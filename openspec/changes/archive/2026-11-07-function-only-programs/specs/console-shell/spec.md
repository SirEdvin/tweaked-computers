# Console shell delta

## MODIFIED Requirements

### Requirement: Guarded native command language
The shell SHALL accept Lua statements, expressions and shell-global assignments using the existing bounded native language and approved globals/libraries shared with saved programs, including `print`. Locals SHALL be scoped to one submission. Host globals, dynamic loading, coroutines, unguarded execution and overwriting reserved API names SHALL remain forbidden. Console syntax SHALL be independent of the declaration-only saved-program grammar and SHALL NOT relax it.

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
- **THEN** the existing expression/statement, guest-table and guarded-call behavior remains available
- **AND** the unchanged retention validator still rejects executable values in the committed shell graph.
