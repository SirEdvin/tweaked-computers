# Program editor redesign delta

Baseline: corresponding capability in `add-native-circuit-computers`; all unmodified requirements remain binding. These deltas do not archive that change.

## MODIFIED Requirements

### Requirement: Single-document authoring
Opening a computer SHALL provide one editable Lua document, validation, Save, Run/Apply, Stop, explicit state reset, status, bounded output and API help. These functions SHALL be organized into Editor, Console, Peripherals, Reference and Maintenance tabs, with Editor selected when first opening a computer. It MUST NOT require filenames, directories, disk commands or a terminal-emulator workflow.

#### Scenario: Author a controller entirely in game
- **WHEN** a player places a computer, opens its editor, types or pastes a handler program, saves and runs it
- **THEN** the edited source becomes executable without an external file or command shell.

#### Scenario: Move between workspaces
- **WHEN** a player switches from Editor to Console, Peripherals, Reference or Maintenance and back
- **THEN** the same draft is retained without saving, activating or resetting the computer.

### Requirement: Usable native GUI and contextual help
The editor SHALL support native text entry/paste, visible keyboard focus, scalable layout, discoverable buttons and actionable status. Help SHALL expose the versioned Lua contract, reachable peripheral names/channels and examples matching shipped behavior. A draggable native title bar, close control and task-specific tab content SHALL replace the all-in-one scrolling form.

#### Scenario: Essential actions without custom shortcuts
- **WHEN** a native text field has keyboard focus
- **THEN** Save, Run/Apply and Stop remain usable through GUI controls without relying on custom-input key events.

#### Scenario: Discover a peripheral from the editor
- **WHEN** the player inspects attached peripherals
- **THEN** the UI distinguishes red and green paths, device types and disconnected/pending status and provides names usable by the Lua API.

## ADDED Requirements

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
