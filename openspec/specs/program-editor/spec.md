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

### Requirement: Method-isolated peripheral reference
The in-game Reference SHALL document each general peripheral discovery method and each shipped device-specific method in its own paragraph, with at least two empty lines between adjacent method paragraphs. Each entry SHALL identify its signature, results and relevant behavior. Aliases SHALL have separate entries. Shared device guidance SHALL remain distinct from method paragraphs, and existing API caveats and examples SHALL remain available.

#### Scenario: Read the discovery API
- **WHEN** a player opens the general peripheral discovery topic
- **THEN** each discovery method has an individually readable paragraph rather than sharing a method list or paragraph with another method
- **AND** adjacent method paragraphs have at least two empty lines between them.

#### Scenario: Read a device method and its alias
- **WHEN** a player reads any shipped device-family topic, including Monitor methods with Color/Colour aliases
- **THEN** each exported method and alias has its own separated paragraph with its signature, results and relevant caveats, or an explicit alias reference to the corresponding method
- **AND** method overloads remain together within that method's paragraph.

#### Scenario: Preserve shared semantics and help tools
- **WHEN** a player browses or searches the reorganized reference
- **THEN** shared wiring, power, persistence, bounds and event guidance remains available without mixing multiple methods into a method paragraph
- **AND** native text selection/copy, existing examples and non-peripheral topics remain available.

### Requirement: Select-then-open peripheral documentation
In the computer's Peripherals tab, a first click on an unselected peripheral SHALL retain the existing identity/status selection behavior without leaving the tab. Clicking the same selected peripheral again on the same discovery wire SHALL open its device-type documentation in Reference, without a double-click timing requirement. Guidance SHALL explain both actions. These actions SHALL NOT save, execute, reset or mutate program or peripheral data.

#### Scenario: First click selects details
- **WHEN** a player clicks an unselected peripheral row
- **THEN** the Peripherals tab remains active and displays that peripheral's API name, type, discovery wire, power status and snapshot details
- **AND** the interface explains that another click opens documentation.

#### Scenario: Repeat click opens the matching topic
- **WHEN** a player clicks that selected peripheral row again, whether immediately or after a delay
- **THEN** Reference becomes active with the documentation for that peripheral's type selected and readable from the beginning
- **AND** the source draft, saved/active revisions, execution, shell values and peripheral data are unchanged.

#### Scenario: Select a different row
- **WHEN** a player clicks another peripheral after selecting one
- **THEN** the new row becomes selected and its details appear without opening Reference
- **AND** another click on the new selection opens that peripheral type's documentation.

#### Scenario: Read documentation for an unpowered peripheral
- **WHEN** an unpowered peripheral appears in the discovery inventory and the player selects then clicks it again
- **THEN** its documentation opens without invoking its service methods or requiring peripheral power.

### Requirement: Reliable contextual reference navigation
Contextual navigation SHALL reveal the requested device topic despite prior filters and keep visible controls consistent. Repeat-click selection SHALL distinguish identity and discovery wire, reset on wire changes or missing/unavailable inventory, and survive same-wire refreshes retaining the identity. Missing documentation SHALL report unavailable rather than display an unrelated topic. Stale or unauthorized GUI events SHALL remain rejected.

#### Scenario: Prior filters hide the requested documentation
- **WHEN** the player repeat-clicks a selected peripheral while an earlier Reference category or search excludes its topic
- **THEN** navigation clears the obstructing search, selects the Peripherals category and selects the matching topic
- **AND** the visible search/category controls agree with that state.

#### Scenario: Change discovery wire
- **WHEN** a player changes the Peripherals discovery wire, including when the same device name is reachable on both colors
- **THEN** the next row click selects identity/status on that wire and does not open documentation until a further click.

#### Scenario: Refresh removes or reorders rows
- **WHEN** a refreshed inventory reorders rows or omits the selected peripheral, or reports pending/error instead of an inventory
- **THEN** row indexes are not treated as peripheral identity, only current row widgets can act, and a missing/unavailable selection cannot trigger documentation navigation
- **AND** if the device later returns, its first click selects it rather than opening documentation immediately.

#### Scenario: An unchanged selection survives refresh
- **WHEN** a successful same-wire refresh still contains the selected peripheral identity
- **THEN** its repeat-click selection remains associated with that identity, not its former row index.

#### Scenario: Documentation mapping is unavailable
- **WHEN** a selected peripheral type has no in-game documentation mapping
- **THEN** the UI retains its details and reports that documentation is unavailable without displaying an unrelated Reference topic.

#### Scenario: Reject stale or foreign clicks
- **WHEN** a click references a destroyed/replaced row widget, another player's session or a computer the player cannot access
- **THEN** it does not change selection, navigate Reference or cause program/peripheral effects.
