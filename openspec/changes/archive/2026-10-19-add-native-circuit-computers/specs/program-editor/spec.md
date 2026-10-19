# Program Editor

## Purpose

Let players introduce, inspect and safely replace event-driven computer code inside Factorio without managing files, an operating system or a command shell.

## ADDED Requirements

### Requirement: Single-document authoring
Opening a computer SHALL provide one editable Lua document, validation, Save, Run/Apply, Stop, explicit state reset, status, bounded output and API help. It MUST NOT require filenames, directories, disk commands or a terminal-emulator workflow.

#### Scenario: Author a controller entirely in game
- **WHEN** a player places a computer, opens its editor, types or pastes a handler program, saves and runs it
- **THEN** the edited source becomes executable without an external file or command shell.

### Requirement: Separate drafts, saved source and active source
An editor draft, saved source revision and running source revision SHALL be distinct. Save SHALL preserve source without changing an active run. Run/Apply SHALL validate a selected saved revision before replacing the run. State SHALL survive replacement unless explicitly reset.

#### Scenario: Save does not interrupt a working factory controller
- **WHEN** a player saves new source while the previous revision is running
- **THEN** the old active revision continues and the UI displays both revision identities until Run/Apply succeeds.

#### Scenario: Invalid replacement preserves the previous run
- **WHEN** compilation or validation of a replacement fails
- **THEN** diagnostics point to the draft/saved source and the existing active run remains unchanged.

### Requirement: Conflict-safe multiplayer editing
Edits SHALL carry a base source revision and require current player authority. A stale save MUST NOT overwrite another player's newer source. The editor SHALL preserve the rejected draft and offer an explicit reviewed reload/rebase path.

#### Scenario: Two players edit the same computer
- **WHEN** one player saves a new revision while another still edits its predecessor
- **THEN** the second save reports a conflict without discarding either the current saved source or the second player's draft.

#### Scenario: Forged or stale GUI event
- **WHEN** an event references a removed computer, another player's editor or an unauthorized force
- **THEN** no source, run status, data or peripheral effects change.

### Requirement: Source-located diagnostics and bounded output
Validation and runtime failures SHALL identify the active/saved revision, handler and original source location where available. Output SHALL be bounded by entries and bytes, with visible truncation. Errors MUST NOT expose host objects, private internals or generated-code-only locations to the player.

#### Scenario: Error after successful actions
- **WHEN** a program faults after previous successful peripheral operations
- **THEN** the console reports the fault and stopped/faulted state without claiming those earlier operations were rolled back.

### Requirement: Safe explicit controls
Run/Apply, Stop and Reset State SHALL be distinct actions. Reset State SHALL require confirmation and a stopped computer. Merely opening, closing, saving or viewing help MUST NOT run source or clear application data.

#### Scenario: Close a dirty editor
- **WHEN** a player closes an editor with unsaved changes
- **THEN** the draft is retained or the player explicitly chooses Save/Discard/Cancel; it is never silently lost.

#### Scenario: Reset while running
- **WHEN** the player requests state reset for a running computer
- **THEN** the UI requires stopping and confirmation before deleting state and does not implicitly clear a KV peripheral.

### Requirement: Usable native GUI and contextual help
The editor SHALL support native text entry/paste, visible keyboard focus, scalable layout, discoverable buttons and actionable status. Help SHALL expose the versioned Lua contract, reachable peripheral names/channels and examples matching shipped behavior.

#### Scenario: Essential actions without custom shortcuts
- **WHEN** a native text field has keyboard focus
- **THEN** Save, Run/Apply and Stop remain usable through GUI controls without relying on custom-input key events.

#### Scenario: Discover a peripheral from the editor
- **WHEN** the player inspects attached peripherals
- **THEN** the UI distinguishes red and green paths, device types and disconnected/pending status and provides names usable by the Lua API.
