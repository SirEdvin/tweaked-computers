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
- **THEN** the old active source continues until Run/Apply succeeds, and Maintenance permits separate reviewed inspection of saved and active source without numeric revision trackers.

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
The editor SHALL support native text entry/paste, visible keyboard focus, scalable layout, discoverable buttons and actionable status. Help SHALL expose the versioned Lua contract, reachable peripheral names/channels and examples matching shipped behavior. Saved-program starters and examples SHALL use function declarations exclusively. A draggable native title bar, close control and task-specific tab content SHALL replace the all-in-one scrolling form.

#### Scenario: Essential actions without custom shortcuts
- **WHEN** a native text field has keyboard focus
- **THEN** Save, Run/Apply and Stop remain usable through GUI controls without relying on custom-input key events.

#### Scenario: Discover a peripheral from the editor
- **WHEN** the player inspects attached peripherals
- **THEN** the UI distinguishes red and green paths, device types and disconnected/pending status and provides names usable by the Lua API.

#### Scenario: Learn and run one saved-program language
- **WHEN** the player inserts an empty-draft starter or manually copies a complete Reference tutorial into the Editor
- **THEN** the copied source uses the declaration grammar and can be validated, saved and run through the normal authoring flow
- **AND** help preserves setup, wiring, API signatures, expected results, relevant failure notes and the separate rules for Console commands
- **AND** browsing, copying, inserting, validating and saving cause no implicit activation or peripheral effects; native literal copying, draft preservation and existing explicit controls remain intact.

### Requirement: Code-first editor and focus layout
The Editor tab SHALL contain the source, one compact action row, concise dirty/run status and contextual diagnostics.

#### Scenario: Editor surface and internal safeguards
- **WHEN** the normal editor or focus layout is displayed
- **THEN** Saved/base/active revision trackers SHALL NOT be displayed, including in Maintenance; internal revisions, generation checks and conflict-safe review SHALL remain unchanged. Console output, peripheral inventories, full reference text and recovery lists MUST NOT occupy the normal editing surface. A reversible focus layout SHALL keep essential controls accessible while removing nonessential navigation chrome.

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
Console SHALL retain bounded selectable output with a user-controlled follow mode.

#### Scenario: Supporting tab accessibility and acquisition
- **WHEN** a supporting tab is opened, refreshed or closed
- **THEN** Peripherals SHALL use meaningful rows with explicit channel and availability. Console and Peripherals SHALL update automatically while open under existing admission bounds, without Refresh controls or numeric update/sample trackers. Hidden/closed panels SHALL NOT poll discovery; automatic updates SHALL preserve identity/selection, unchanged rows, source focus and scrolling. Reference SHALL expose complete existing help and examples by topic. Maintenance SHALL retain every existing recovery/reset action. Text and symbols SHALL supplement color; all essential actions SHALL remain accessible at supported GUI scales.

#### Scenario: Review logs without scroll fighting
- **WHEN** the player disables Console follow and new output arrives
- **THEN** the interface does not repeatedly force the visible log position to the newest entry.
- **AND** the single selectable text box continues receiving live output; changed text may reset native selection, unchanged text is not reassigned, and re-enabling Follow resumes tailing. Existing bounded-history eviction remains visible and cannot recover discarded bytes.

#### Scenario: Recover a removed computer's draft
- **WHEN** the original computer is gone and the player Ctrl-clicks another accessible computer body
- **THEN** Maintenance permits reviewed draft replacement and confirmed forget without executing source or deleting drafts automatically.

#### Scenario: Recover at draft capacity
- **WHEN** all eight draft slots are occupied and the player Ctrl-clicks a new accessible computer body
- **THEN** the standalone capacity viewer permits review/native copy and confirmed forget without executing source or evicting drafts.

#### Scenario: Resize or increase GUI scale
- **WHEN** display resolution or GUI scale changes
- **THEN** navigation, close, source and essential controls remain reachable, source is retained, and the window is clamped to the available screen rather than clipped beyond it.

### Requirement: Computer-body-only world activation
The shared world gesture SHALL open computer UI only for the selected valid registered computer body, under existing cursor, GUI, permission, reach, force and surface guards. It SHALL NOT resolve nearby computers, helpers or ghosts. Empty ground SHALL remain inert even with retained drafts. Intentional position-based monitor touch and native Ctrl-click inventory transfers SHALL remain unchanged.

#### Scenario: Empty ground with or without drafts
- **WHEN** the player Ctrl-clicks empty ground, with no monitor cell at the cursor
- **THEN** no computer workspace or recovery viewer opens and retained drafts remain unchanged.

#### Scenario: Unrelated or invalid target
- **WHEN** the gesture targets a vanilla entity, unrelated peripheral, helper, ghost, unregistered or removed body
- **THEN** no computer UI opens and no nearby computer is substituted.

### Requirement: Console and saved-source isolation
The optional Console Lua input SHALL follow the independent `console-shell` contract. It SHALL NOT become a prerequisite for authoring, saving or activating the source document, and its commands, drafts, state and reset controls SHALL remain distinct from saved-program editing and explicit application state.

#### Scenario: Experiment without replacing saved source
- **WHEN** a player submits a Console command while editing a saved handler program
- **THEN** the command follows the Console admission and ownership rules without saving, activating or overwriting the player's source draft.

### Requirement: Method-isolated peripheral reference
The in-game Reference SHALL document each general peripheral discovery method and each shipped device-specific method in its own visibly separated native section.

#### Scenario: Separated method documentation
- **WHEN** a peripheral method is presented in Reference
- **THEN** Each entry SHALL distinguish its literal signature from wrapped results, arguments and relevant caveats. Aliases SHALL have separate entries; overloads SHALL remain together. Shared device guidance SHALL remain distinct from method sections. Readability SHALL be structural, not dependent on a count of blank lines in a plain text box, and existing API caveats SHALL remain available.

#### Scenario: Read the discovery API
- **WHEN** a player opens the general peripheral discovery topic
- **THEN** each discovery method has an individually readable paragraph rather than sharing a method list or paragraph with another method
- **AND** adjacent methods have separate selectable signature and result/notes blocks with visible spacing.

#### Scenario: Read a device method and its alias
- **WHEN** a player reads any shipped device-family topic, including Monitor methods with Color/Colour aliases
- **THEN** each exported method and alias has its own separated paragraph with its signature, results and relevant caveats, or an explicit alias reference to the corresponding method
- **AND** method overloads remain together within that method's paragraph.

#### Scenario: Preserve shared semantics and help tools
- **WHEN** a player browses or searches the reorganized reference
- **THEN** shared wiring, power, persistence, bounds and event guidance remains available without mixing multiple methods into a method paragraph
- **AND** native text selection/copy, existing examples and non-peripheral topics remain available.

### Requirement: Consistent selectable Reference documents
Every topic, including Workflow, Language, Computer, Safety and examples, SHALL use native heading hierarchy, short wrapped paragraphs or lists, and distinct literal code.

#### Scenario: Literal and side-effect-free Reference browsing
- **WHEN** the player reads or copies Reference content
- **THEN** Prose SHALL NOT require horizontal scrolling at supported effective widths. Useful headings, prose, signatures and code SHALL remain manually selectable/copyable with native controls. Code SHALL retain exact whitespace and literal bracket bytes without rich-text or Markdown interpretation. Reference SHALL have no Select text or Insert starter action buttons; the unrelated empty-draft Editor starter and recovery controls SHALL remain available. Browsing SHALL NOT edit drafts, save/activate/stop/reset code, reset shell values or mutate peripheral data.

#### Scenario: Read and copy a complete tutorial
- **WHEN** a player opens any embedded starter, speaker, logic, Recipe Searcher, factory or shared-data tutorial
- **THEN** it includes purpose, research/entities/power/exact wiring, complete runnable code, authoring/execution steps, expected visible results and relevant failure/safety notes without requiring an external file
- **AND** shared data explicitly requires two computers and two physical databases, with both complete programs available in the topic.

#### Scenario: Preserve literal copy and navigation
- **WHEN** the player manually selects/copies code or prose, filters by instructional or code text, changes category/topic or opens contextual help
- **THEN** native copy preserves the selected bytes, prose wraps independently of copied bytes, code remains literal, and no Reference action mutates a draft or executes code
- **AND** all existing exact-type mappings, filter clearing, ownership checks, dirty draft/widget/focus and saved-versus-running separation remain intact.

### Requirement: Select-then-open peripheral documentation
In the computer's Peripherals tab, a first click on an unselected peripheral SHALL retain the existing identity/status selection behavior without leaving the tab. Clicking the same selected peripheral again on the same discovery wire SHALL open its device-type documentation in Reference, without a double-click timing requirement. Guidance SHALL explain both actions. These actions SHALL NOT save, execute, reset or mutate program or peripheral data.

#### Scenario: First click selects details
- **WHEN** a player clicks an unselected peripheral row
- **THEN** the Peripherals tab remains active and displays that peripheral's API name, type, discovery wire and power status without snapshot metadata
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

### Requirement: Elapsed map timestamps in Console
Each Console log entry SHALL display its recorded map tick as `[HH:MM:SS]`, using completed simulation seconds at 60 ticks per second. Hours SHALL be cumulative and padded to at least two digits; minutes and seconds SHALL have exactly two digits. The prefix SHALL describe when the entry occurred, not its age, local wall-clock time or time since the computer started.

#### Scenario: Zero and subsecond entries
- **WHEN** entries recorded at ticks 0, 59 and 60 are displayed
- **THEN** their prefixes are `[00:00:00]`, `[00:00:00]` and `[00:00:01]` respectively
- **AND** entries sharing a displayed second retain their original order.

#### Scenario: Minute and hour rollover
- **WHEN** entries recorded at ticks 3599, 3600, 215999 and 216000 are displayed
- **THEN** their prefixes are `[00:00:59]`, `[00:01:00]`, `[00:59:59]` and `[01:00:00]` respectively.

#### Scenario: Long-running maps do not wrap or truncate hours
- **WHEN** entries recorded at ticks 5184000, 5846940 and 21600000 are displayed
- **THEN** their prefixes are `[24:00:00]`, `[27:04:09]` and `[100:00:00]` respectively
- **AND** no day field or daily rollover replaces the cumulative hour count.

#### Scenario: Computer and interface lifecycle do not reset the origin
- **WHEN** the Console is reopened or the computer is stopped and restarted
- **THEN** retained entries keep the same elapsed timestamp
- **AND** new entries use their occurrence on the same map timeline rather than a new computer-session origin.

#### Scenario: Simulation timing is not a wall clock
- **WHEN** the simulation is paused, its speed changes, or an old entry is viewed later
- **THEN** the entry's prefix remains derived only from its recorded map tick
- **AND** neither real-world waiting time nor the viewing player's clock changes that prefix.

### Requirement: Display-only timestamp compatibility
Timestamp formatting SHALL preserve stored log ticks and text, ordering, retention bounds and truncation behavior. Program output, shell echoes/results and logged errors SHALL share the same timestamp format without losing attribution or diagnostics. Existing tab-to-space display normalization, literal selectable output, Follow behavior and suppression of unchanged-text writes SHALL remain intact. No save migration SHALL be required.

#### Scenario: Existing saved history remains readable
- **WHEN** a save containing retained tick-based log entries is loaded and its Console is opened
- **THEN** the retained entries display elapsed map timestamps without rewriting their ticks or text, changing retained byte accounting or replaying the logged actions
- **AND** saving and loading again preserves the same history and displayed timestamps.

#### Scenario: Program and shell output use one format
- **WHEN** program messages, shell command echoes, shell results and logged failures are displayed together
- **THEN** every retained entry uses the elapsed timestamp format in its existing position
- **AND** message text, shell command attribution, diagnostic details, newlines and tab-to-space display normalization remain otherwise unchanged.

#### Scenario: Refresh without new output
- **WHEN** the current map tick advances but retained Console entries and diagnostics have not changed
- **THEN** timestamp formatting does not change the displayed text or trigger another text assignment
- **AND** existing native selection and copying remain available between actual output updates.

#### Scenario: Follow and bounded history remain unchanged
- **WHEN** new entries arrive while Follow is disabled and existing retention bounds evict old output
- **THEN** the Console displays the retained entries with elapsed timestamps without forcing a scroll to the newest entry
- **AND** truncation remains visible and enabling Follow resumes the existing tailing behavior.
