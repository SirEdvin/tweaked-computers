# peripheral-inspection Specification

## Purpose

Let players inspect physical peripherals directly through safe, read-only native windows, identify their exact program-facing names and copy those names without running diagnostic programs.

## Requirements

### Requirement: Native inspection for every peripheral family
The mod SHALL provide a device-local inspector for KV Database, Monitor, Logic Handler, Configurator, Recipe Searcher, Factoriopedia Interface and Production Statistics through normal entity opening. The window SHALL identify the logical device rather than a helper. Recipe Searcher, Factoriopedia Interface and Production Statistics SHALL receive basic identity/status inspection, not recipe-search, catalogue or statistics-query interfaces. Computers SHALL retain their existing workspace.

#### Scenario: Open each peripheral
- **WHEN** an authorized player uses normal entity-open on any of these peripheral families
- **THEN** its inspector opens without exposing the carrier's native configuration controls
- **AND** no computer connection or running program is required to inspect the device locally.

#### Scenario: Existing device after upgrade
- **WHEN** a supported existing save is upgraded without replacing its peripherals
- **THEN** the same devices support ordinary inspector opening while retaining identities, wires, data and output ownership.

#### Scenario: Basic Factoriopedia Interface inspector
- **WHEN** an authorized player normally opens a powered or unpowered Factoriopedia Interface
- **THEN** the exact peripheral name is copyable and its type and availability are visible through the existing player-scoped inspector
- **AND** opening or refreshing performs no item/fluid catalogue enumeration, metadata query, world mutation or guest execution.

#### Scenario: Basic Production Statistics inspector
- **WHEN** an authorized player opens a powered or unpowered statistics device
- **THEN** its exact peripheral name remains selectable/copyable and its availability is explicit
- **AND** opening or refreshing the inspector performs no production-statistics queries, exposes no force/surface selector and executes no guest program.

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
Normal peripheral opening SHALL inspect rather than emit a monitor touch. Ctrl-click monitor touches, guarded Ctrl-click computer-body editing, native inventory transfers and cardinal rotation SHALL retain their existing behavior. Empty-ground clicks SHALL NOT open computer UI, even with retained drafts. Draft recovery SHALL remain accessible through another computer's Maintenance or the capacity viewer when opening a computer with all draft slots occupied. Owned helper dialogs SHALL remain inaccessible, and unrelated entity windows SHALL NOT be replaced.

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
Inspectors SHALL poll automatically with coalesced scheduling, preserve selections and unchanged mounted content, and stop detail polling when closed. They SHALL show meaningful pending/unavailable states, not incomplete results as complete. Logic observations SHALL use direct native reads without inventory ceilings or revalidation; presentation scheduling SHALL not limit accessible signals. Other families retain their existing allowances. Refresh buttons and numeric tick trackers SHALL remain absent.

#### Scenario: Repeated refresh under contention
- **WHEN** multiple players inspect peripherals while programs and monitors are active
- **THEN** UI work is coalesced without an unbounded request backlog or renewed same-tick credits
- **AND** scheduling presentation does not turn a large Logic Handler inventory into a size refusal or a cache for program reads.

#### Scenario: Snapshot cannot be refreshed
- **WHEN** a non-logic query exceeds its existing allowance or a logic target becomes unavailable
- **THEN** the UI identifies pending/error status and does not publish a partial result as complete
- **AND** previous displayed details are marked stale, while unresolved monitor identities cannot be copied as current.

#### Scenario: Initial query cannot be admitted
- **WHEN** an inspector opens before its refresh is scheduled
- **THEN** identity, controls and meaningful pending detail structure appear without claiming an empty successful result.

#### Scenario: Large native circuit with optional fields
- **WHEN** a Logic Handler has more than 1,024 signals, including records with omitted default identity fields
- **THEN** every entry is accessible with its correct effective identity, wire and count, without sorting or expanding source records
- **AND** fresh refreshes observe native values independently of subscriptions while retaining the user's scroll, focus and copy selection where content is unchanged.

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
