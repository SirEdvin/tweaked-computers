# peripheral-inspection Specification

## Purpose

Let players inspect physical peripherals directly through safe, read-only native windows, identify their exact program-facing names and copy those names without running diagnostic programs.

## Requirements

### Requirement: Native inspection for every peripheral family
The mod SHALL provide a device-local inspector for KV Database, Monitor, Logic Handler, Configurator and Recipe Searcher through normal entity opening. The window SHALL identify the logical device rather than a helper. Recipe Searcher SHALL receive basic identity/status inspection, not a recipe-search interface. Computers SHALL retain their existing workspace.

#### Scenario: Open each peripheral
- **WHEN** an authorized player uses normal entity-open on any of the five peripheral families
- **THEN** its inspector opens without exposing the carrier's native configuration controls
- **AND** no computer connection or running program is required to inspect the device locally.

#### Scenario: Existing device after upgrade
- **WHEN** a supported existing save is upgraded without replacing its peripherals
- **THEN** the same devices support ordinary inspector opening while retaining identities, wires, data and output ownership.

### Requirement: Exact copyable peripheral identity
Every inspector SHALL show the localized device name, peripheral type, availability and exact name used by peripheral discovery. The API name SHALL be read-only and selectable, with an explicit action that selects it for native Copy. Copy selection SHALL contain only the identifier, without labels, quotes or added whitespace. Inspection SHALL NOT rename devices.

#### Scenario: Copy into a computer program
- **WHEN** a player selects the API name using the inspector's copy-selection action, invokes native Copy and pastes into a text field
- **THEN** the pasted bytes equal the displayed peripheral identifier exactly
- **AND** the action does not claim clipboard success merely because it selected text.

#### Scenario: Basic Recipe Searcher inspector
- **WHEN** the Recipe Searcher inspector is open
- **THEN** its name and status can be inspected and copied without invoking a recipe query or offering crafting/storage controls.

### Requirement: Inspection and existing gestures remain distinct
Normal peripheral opening SHALL inspect rather than emit a monitor touch. Ctrl-click monitor touches, Ctrl-click computer editing, empty-ground draft recovery, native inventory transfers and cardinal rotation SHALL retain their existing behavior. Owned helper dialogs SHALL remain inaccessible, and unrelated entity windows SHALL NOT be replaced.

#### Scenario: Inspect then touch a monitor
- **WHEN** a player normally opens a monitor, closes the inspector and then Ctrl-clicks a valid display cell
- **THEN** opening produces no touch, and the later Ctrl-click produces the existing authorized touch behavior without opening an inspector.

#### Scenario: Existing computer and native controls
- **WHEN** a player Ctrl-clicks a computer, rotates a peripheral or uses Ctrl with vanilla inventory controls
- **THEN** those actions keep their established behavior without duplicate rotation, lost drafts or an unwanted peripheral window.

### Requirement: Player-scoped read authority
Opening, refreshing and acting on an inspector SHALL revalidate the player, exact device identity, same force, same surface, reach and applicable permissions. Each window SHALL belong to one player's current session. Stale, forged, foreign or replacement-target events SHALL fail closed without exposing new data or mutating device state.

#### Scenario: Device replaced at the same position
- **WHEN** an inspected device is removed and a new device is placed at its coordinates
- **THEN** the old session becomes unavailable rather than retargeting the replacement.

#### Scenario: Player loses access
- **WHEN** an inspecting player changes force or surface, moves out of reach, loses permission, dies or disconnects
- **THEN** the window is closed or made unavailable on the next authority check, its detail data is no longer refreshed, and later GUI events cannot read through the old session.

#### Scenario: Two simultaneous viewers
- **WHEN** two authorized players inspect one peripheral and one closes or refreshes their window
- **THEN** the other player's selection and window remain independent, without creating a device writer or executing a program.

### Requirement: Non-mutating inspection and explicit availability
Inspectors SHALL NOT execute guest code, edit data/configuration, create subscriptions, claim output ownership or alter display contents. Identity/status inspection SHALL remain available without power. KV contents, target inventories and live logic input queries SHALL respect service power restrictions; unavailable details SHALL be labelled rather than represented as an empty successful result.

#### Scenario: Unpowered peripheral
- **WHEN** an authorized player opens an unpowered peripheral
- **THEN** the name remains copyable and the UI explicitly reports unpowered status
- **AND** active detail queries are not performed, retained data is not erased and old detail snapshots are not presented as current.

#### Scenario: Browse without effects
- **WHEN** a player opens, selects, refreshes and closes a powered inspector
- **THEN** database values/deadlines, factory settings, output ownership, program state and monitor model revisions remain unchanged by inspection.

### Requirement: Bounded and honest refresh
Inspectors SHALL show meaningful pending content before query admission and bound work, snapshots and GUI elements within unchanged shared host allowances. All open inspectors, including KV and Configurator, SHALL poll automatically through throttled, coalesced scheduler admission. Refresh controls and numeric update/sample tick trackers SHALL NOT be displayed, including logic subpanels. Incomplete results SHALL be marked pending/stale/error, never a successful empty inventory or complete partial count. Closed/hidden inspectors SHALL perform no detail polling. Automatic updates SHALL retain key/field/page selection and mounted unchanged rows/text rather than recreating them on each observation.

#### Scenario: Repeated refresh under contention
- **WHEN** multiple players repeatedly request inspection while programs and monitors are active
- **THEN** excess work is deferred within unchanged global ceilings, no unbounded request backlog accumulates and already-spent same-tick credits remain spent across save/load.

#### Scenario: Snapshot cannot be refreshed
- **WHEN** the required query cannot complete within its work or data allowance
- **THEN** the UI identifies the refusal or pending state and does not publish a partial result as current.
- **AND** any previous complete detached details remain visible as explicitly stale, while unresolved monitor identities cannot be copied as current.

#### Scenario: Initial query cannot be admitted
- **WHEN** any supported peripheral inspector opens before data-query work is available
- **THEN** its identity, controls and meaningful pending detail structure are visible without claiming an empty successful result.

### Requirement: Usable native inspection layout
Inspectors SHALL provide localized headings/actions, dragging, close/Escape, bounded scrolling and reachable controls at supported resolutions and scales. Text and tooltips SHALL supplement color. Long static guidance SHALL live in tooltips or Reference; meaningful status and safety states SHALL remain visible. Unchanged refreshes SHALL preserve copy/detail selection, focus and scroll position.

#### Scenario: Read while data changes
- **WHEN** values or status update while the player reads or selects an unchanged name
- **THEN** the window does not steal focus, repeatedly replace unchanged text or reset the player's browsing position.

#### Scenario: Escape or another window
- **WHEN** the player closes the inspector, presses Escape or opens another native window
- **THEN** the inspector retires without reopening over the next window or discarding a retained computer draft.

### Requirement: Safe save and lifecycle handling
Save/load SHALL NOT perform inspection work or mutate device data during load. Retained inspector state SHALL be revalidated during synchronized gameplay before new detail queries or actions. Removal, force/surface changes and incompatible UI versions SHALL invalidate only affected inspection sessions without damaging retained device or editor data.

#### Scenario: Cold load with an open inspector
- **WHEN** a save containing an open inspector is loaded in a separate process
- **THEN** load executes no query or guest callback, and subsequent gameplay either restores a revalidated inspector or safely closes it with the device data intact.
