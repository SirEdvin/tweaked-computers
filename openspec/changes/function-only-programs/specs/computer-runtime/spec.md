# Computer runtime delta

## MODIFIED Requirements

### Requirement: Native named-handler execution
The saved-program runtime SHALL execute one active function-declaration document using named, non-suspending native Lua handlers conforming to the `program-source` contract and `lua-api.md`. It MUST NOT interpret Lua instructions, introduce a VM fallback, expose a filesystem, or emulate an operating-system shell. The independent Console SHALL obey the bounded `console-shell` contract; it does not relax saved-handler syntax, create background callbacks or replace the saved program.

#### Scenario: Start an event-driven program
- **WHEN** the player runs a valid document defining an exported `start` function
- **THEN** the computer begins a new run generation and invokes that handler once
- **AND** subsequent callbacks run only for registered events, subscriptions or timers.

#### Scenario: Reject unsupported execution features
- **WHEN** a document requests an unsupported language feature, dynamic code loading, coroutine suspension or forbidden host access
- **THEN** validation reports a source-located diagnostic before activation
- **AND** the previous valid active program is not replaced.

#### Scenario: Validate and reconstruct the same language
- **WHEN** a saved candidate is validated for activation or an accepted active source is reconstructed for dispatch
- **THEN** both operations enforce the same declaration-only grammar and named-handler rules
- **AND** neither stored metadata nor caller-supplied generated text bypasses source validation or selects another execution path.
