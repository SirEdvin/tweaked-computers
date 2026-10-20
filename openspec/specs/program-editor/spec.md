# program-editor Specification

## Purpose

Let players introduce, inspect and safely replace event-driven computer code inside Factorio without managing files, an operating system or a command shell.

## Requirements

### Requirement: Single-document authoring
Opening a computer SHALL provide one editable Lua document, validation, Save, Run/Apply, Stop, explicit state reset, status, bounded output and API help. These functions SHALL be organized into Editor, Console, Peripherals, Reference and Maintenance tabs, with Editor selected when first opening a computer. It MUST NOT require filenames, directories, disk commands or a terminal-emulator workflow.

#### Scenario: Author a controller entirely in game
- **WHEN** a player places a computer, opens its editor, types or pastes a handler program, saves and runs it
- **THEN** the edited source becomes executable without an external file or command shell.

#### Scenario: Move between workspaces
- **WHEN** a player switches from Editor to Console, Peripherals, Reference or Maintenance and back
- **THEN** the same draft is retained without saving, activating or resetting the computer.

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
The editor SHALL support native text entry/paste, visible keyboard focus, scalable layout, discoverable buttons and actionable status. Help SHALL expose the versioned Lua contract, reachable peripheral names/channels and examples matching shipped behavior. A draggable native title bar, close control and task-specific tab content SHALL replace the all-in-one scrolling form.

#### Scenario: Essential actions without custom shortcuts
- **WHEN** a native text field has keyboard focus
- **THEN** Save, Run/Apply and Stop remain usable through GUI controls without relying on custom-input key events.

#### Scenario: Discover a peripheral from the editor
- **WHEN** the player inspects attached peripherals
- **THEN** the UI distinguishes red and green paths, device types and disconnected/pending status and provides names usable by the Lua API.

### Requirement: Code-first editor and focus layout
The Editor tab SHALL contain the source, one compact action row, concise revision/run status and contextual diagnostics. Console output, peripheral inventories, full reference text and recovery lists MUST NOT occupy the normal editing surface. A reversible focus layout SHALL keep essential controls accessible while removing nonessential navigation chrome.

#### Scenario: Open a normal editing session
- **WHEN** the Editor tab opens at a supported display size
- **THEN** code is the dominant content region, no whole-window scroll is needed to reach Save or Stop, and no console/help/recovery stack competes with the source.

#### Scenario: Toggle focus with dirty source
- **WHEN** focus layout is entered and exited while the draft has unsaved changes
- **THEN** draft bytes and active execution remain unchanged, and the source widget is not replaced merely to toggle chrome.

### Requirement: Contextual actions and restrained updates
Save SHALL remain separate from activation. The UI SHALL show one contextual Run or Apply action, not duplicate activation buttons. Reset/forget/recovery controls SHALL live in Maintenance with explicit confirmations. Status refreshes MUST NOT overwrite source, steal typing focus, rebuild the editor or force the player to another tab.

#### Scenario: Live output while editing
- **WHEN** a running program emits output or faults while the player edits source
- **THEN** an actionable status or Console badge updates without replacing the source, losing edits or automatically switching tabs.

#### Scenario: Conflict needs attention
- **WHEN** another player changes the saved revision
- **THEN** the current draft survives, a compact conflict notice offers reviewed resolution, and no automatic reload, save or activation occurs.

### Requirement: Accessible bounded supporting tabs
Console SHALL retain bounded selectable output with a user-controlled follow mode. Peripherals SHALL use meaningful rows with explicit channel and availability. Reference SHALL expose complete existing help and examples by topic. Maintenance SHALL retain every existing recovery/reset action. Text and symbols SHALL supplement color; all essential actions SHALL remain accessible at supported GUI scales.

#### Scenario: Review logs without scroll fighting
- **WHEN** the player disables Console follow and new output arrives
- **THEN** the interface does not repeatedly force the visible log position to the newest entry.

#### Scenario: Recover without an accessible computer
- **WHEN** the computer is gone or draft capacity is exhausted
- **THEN** the standalone recovery entry remains available and permits reviewed copy/forget without executing source.

#### Scenario: Resize or increase GUI scale
- **WHEN** display resolution or GUI scale changes
- **THEN** navigation, close, source and essential controls remain reachable, source is retained, and the window is clamped to the available screen rather than clipped beyond it.

### Requirement: Console and saved-source isolation
The optional Console Lua input SHALL follow the independent `console-shell` contract. It SHALL NOT become a prerequisite for authoring, saving or activating the source document, and its commands, drafts, state and reset controls SHALL remain distinct from saved-program editing and explicit application state.

#### Scenario: Experiment without replacing saved source
- **WHEN** a player submits a Console command while editing a saved handler program
- **THEN** the command follows the Console admission and ownership rules without saving, activating or overwriting the player's source draft.
