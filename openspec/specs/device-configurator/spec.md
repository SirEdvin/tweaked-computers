# device-configurator Specification

## Purpose

Let computer programs enumerate factory devices connected to a configurator's separate target circuit networks, inspect their locations and supported settings, and safely configure the complete pinned circuit-control surface.

## Requirements

### Requirement: Separate computer and target connections
The configurator SHALL occupy a rotatable 2×1 footprint with distinct computer-network and target-device roles. Each role SHALL have red/green connectors. Target-device cables MUST NOT extend the computer discovery graph.

#### Scenario: Connected factory and computer networks
- **WHEN** the computer is connected to the network role and an inserter network to the target role
- **THEN** the computer can call the configurator without becoming a directly connected circuit endpoint of those inserters.

### Requirement: Complete bounded target enumeration
The API SHALL enumerate every same-force device reachable on the selected red or green target-side native wire network within the supported envelope. Traversal SHALL include ordinary relays but MUST NOT cross a combinator's isolated input/output roles, change color or surface, or follow ghost wires.

#### Scenario: Devices reached through a pole
- **WHEN** a target wire reaches a pole and then several machines
- **THEN** all reachable real devices are listed once with complete-result semantics, including devices without configurable circuit behavior.

#### Scenario: Unsupported target graph size
- **WHEN** the full traversal cannot complete within declared limits
- **THEN** the API reports an explicit limit/pending error instead of returning an unmarked partial list.

### Requirement: Stable descriptive device records
Each listed device SHALL provide an opaque identity, prototype name, entity type, coordinates, surface, direction, quality, connectivity and configuration availability. Coordinates and labels MUST NOT be authority tokens. Raw Factorio objects and owned implementation helpers MUST NOT be exposed.

#### Scenario: Same coordinates after replacement
- **WHEN** a target is destroyed and replaced at the same coordinates
- **THEN** its old identifier cannot configure the replacement and discovery supplies a new identifier.

### Requirement: Full pinned circuit-control coverage
The configurator SHALL describe and support every writable setting exposed by Factorio 2.0.77 circuit-control behavior interfaces, including inherited fields and constant-combinator sections. `configuration-catalog.json` and `configuration-catalog.md` SHALL inventory this surface; native constraints SHALL remain explicit.

#### Scenario: Not merely enable/disable
- **WHEN** a compatible target exposes combinator parameters, train-stop controls, recipe controls, lamp colors, display-panel messages or other catalogued settings
- **THEN** discovery reports their typed capabilities and the corresponding documented operations are supported.

#### Scenario: Expansion or modded native entity
- **WHEN** an installed expansion/mod supplies an entity using a supported native control-behavior class
- **THEN** its applicable settings are exposed without requiring a guest extension API or assuming its prototype belongs to base.

### Requirement: Typed capability and configuration snapshots
Capabilities SHALL include readable/writable state, value types, nested fields, enums, numeric bounds, nullability and applicability restrictions. Configuration reads SHALL return normalized defensive plain data and distinguish unsupported, unset and false values.

#### Scenario: Read an inserter's configuration
- **WHEN** a program inspects a reachable inserter
- **THEN** it can discover `circuit_enable_disable`, `circuit_condition`, `circuit_set_filters` and other available settings with their current values and schema.

#### Scenario: Read-only evaluated condition
- **WHEN** a condition exposes its current fulfillment result
- **THEN** that result is described as read-only and cannot be written back as a user-controlled setting.

### Requirement: Validated device-scoped updates
Updates SHALL validate target reachability, setting paths, types, enums, prototypes, quality, limits and inter-field constraints before changing the target. Unknown or read-only fields SHALL be rejected. A rejected update MUST NOT partially change valid fields included in the same request.

#### Scenario: Mixed valid and invalid patch
- **WHEN** a patch enables circuit control but also contains an invalid signal identity
- **THEN** neither change is applied and the error identifies the invalid field.

#### Scenario: Explicitly clear a nullable condition
- **WHEN** a patch lists a clearable condition in its explicit clear list
- **THEN** that condition is cleared without treating missing fields as implicit clears.

### Requirement: Native section and shared-group boundaries
Constant-combinator sections SHALL be inspectable and editable through bounded plain-data operations equivalent to the pinned section API. Nonmanual sections SHALL remain protected. Editing a shared group's contents MUST NOT modify devices outside the caller's target authority; denied shared-scope edits SHALL be explicit.

#### Scenario: Edit a protected section
- **WHEN** a program attempts to mutate or remove a nonmanual section
- **THEN** the operation is refused without altering adjacent sections.

#### Scenario: Shared group exceeds target authority
- **WHEN** changing a group's contents would change an unconnected device
- **THEN** that edit is refused with a shared-scope diagnostic
- **AND** the caller can inspect the group reference and explicitly detach the selected manual section before local editing.

### Requirement: Persistent factory settings and shared writers
Successful updates SHALL change the actual target's native configuration and remain after the writer stops, disconnects or the configurator is removed. Concurrent authorized updates SHALL follow deterministic last-successful-write semantics. The configurator MUST NOT become an undocumented periodic settings-enforcement service.

#### Scenario: Player later changes a configured device
- **WHEN** the player edits a target after a successful program update
- **THEN** the player's new setting remains until another explicit update; merely reading or reconnecting the configurator does not overwrite it.

### Requirement: Safe stale-target and unsupported-device results
Every target operation SHALL revalidate current identity and target-port reachability. Connected devices without supported control behavior SHALL remain visible with a reason and empty/limited capabilities rather than being omitted or accepting arbitrary property writes.

#### Scenario: Target is disconnected after enumeration
- **WHEN** a program submits an update using a previously listed device ID after its cable is removed
- **THEN** the update is rejected and the target remains unchanged.

### Requirement: Prototype-grouped target inventory
The configurator inspector SHALL list target-side factory devices grouped by exact entity prototype, with a localized name, prototype identity and count for each group. Broad entity type alone SHALL NOT merge different prototypes. Enumeration SHALL retain existing same-force, same-surface, real-wire traversal rules and include connected targets without writable circuit settings.

#### Scenario: Several inserter prototypes
- **WHEN** target wires reach several devices of one inserter prototype and devices of another inserter prototype
- **THEN** each prototype appears as a separate counted group rather than one generic inserter total.

#### Scenario: Unsupported connected targets and ordinary relays
- **WHEN** a target network reaches ordinary relay poles or devices without writable control behavior
- **THEN** those reachable devices remain counted under their actual prototypes instead of disappearing from the inventory.

### Requirement: Explicit wire membership and unique totals
The inventory SHALL show each prototype group's red-connected count, green-connected count and unique total across both target networks. An entity reachable on both colors SHALL count once in the unique total and once in each applicable color count. The configurator itself and owned helper entities SHALL NOT appear as extra devices; network-role-only peripherals SHALL NOT enter the target inventory.

#### Scenario: Device reached on both colors
- **WHEN** one machine is reachable through red and green target paths, including multiple paths on either color
- **THEN** its group shows one unique device, one red-connected device and one green-connected device
- **AND** the labels explain that red and green counts overlap rather than promising their sum equals the unique total.

#### Scenario: Separate discovery and target networks
- **WHEN** peripherals are attached only to the configurator's computer-network role and factory machines to its target role
- **THEN** the inventory counts only the target-side reachable entities without adding discovery devices or crossing isolated combinator roles.

### Requirement: Complete bounded inventory refresh
The inspector SHALL update its target inventory automatically while open under existing scheduler admission, without a Refresh control or numeric snapshot tick. Counts SHALL be published only from complete admitted target-network observations; incomplete or over-limit traversal SHALL report pending/error rather than a plausible partial total. Display rows SHALL be deterministically ordered and bounded, with all successful groups reachable by scrolling or pagination.

#### Scenario: Wire removed before refresh
- **WHEN** a target loses its last qualifying connection and the open inspector next polls automatically
- **THEN** the new complete snapshot removes it from the applicable group and color counts without changing any machine settings.

#### Scenario: One wire cannot be enumerated
- **WHEN** either color's traversal cannot complete within supported graph/work limits
- **THEN** the UI does not claim a complete combined inventory or unique total
- **AND** any retained prior snapshot is explicitly stale rather than mixed with new partial counts.
