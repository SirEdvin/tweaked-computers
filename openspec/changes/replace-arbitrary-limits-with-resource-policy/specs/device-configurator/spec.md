## MODIFIED Requirements

### Requirement: Complete bounded target enumeration
The API SHALL enumerate every same-force device reachable on the selected red or green target-side native wire network without independent mod node/edge/result ceilings. Traversal SHALL include ordinary relays but MUST NOT cross a combinator's isolated input/output roles, change color or surface, or follow ghost wires.

#### Scenario: Devices reached through a pole
- **WHEN** a target wire reaches a pole and then several machines
- **THEN** all reachable real devices are listed once with complete-result semantics, including devices without configurable circuit behavior.

#### Scenario: Unsupported target graph size
- **WHEN** the full traversal needs more than the current work slice
- **THEN** the API resumes its proof across ticks and returns only a complete list; hard-resource inability is recoverable, not an unmarked partial list.

### Requirement: Validated device-scoped updates
Updates SHALL validate target reachability, setting paths, types, enums, prototypes, quality, actual native constraints, configured resource admission and inter-field constraints before changing the target. Unknown or read-only fields SHALL be rejected. A rejected update MUST NOT partially change valid fields included in the same request.

#### Scenario: Mixed valid and invalid patch
- **WHEN** a patch enables circuit control but also contains an invalid signal identity
- **THEN** neither change is applied and the error identifies the invalid field.

#### Scenario: Explicitly clear a nullable condition
- **WHEN** a patch lists a clearable condition in its explicit clear list
- **THEN** that condition is cleared without treating missing fields as implicit clears.

### Requirement: Native section and shared-group boundaries
Constant-combinator sections SHALL be inspectable and editable through resource-accounted plain-data operations equivalent to the pinned section API, without mod-specific section/filter/slot/array or string-size ceilings. Nonmanual sections SHALL remain protected. Editing a shared group's contents MUST NOT modify devices outside the caller's target authority; denied shared-scope edits SHALL be explicit.

#### Scenario: Edit a protected section
- **WHEN** a program attempts to mutate or remove a nonmanual section
- **THEN** the operation is refused without altering adjacent sections.

#### Scenario: Shared group exceeds target authority
- **WHEN** changing a group's contents would change an unconnected device
- **THEN** that edit is refused with a shared-scope diagnostic
- **AND** the caller can inspect the group reference and explicitly detach the selected manual section before local editing.

### Requirement: Complete bounded inventory refresh
The inspector SHALL update its target inventory automatically while open under existing scheduler admission, without a Refresh control or numeric snapshot tick. Counts SHALL be published only from complete admitted target-network observations; incomplete or resource-refused traversal SHALL report pending/error rather than a plausible partial total. Display rows SHALL be deterministically ordered and bounded, with all successful groups reachable by scrolling or pagination.

#### Scenario: Wire removed before refresh
- **WHEN** a target loses its last qualifying connection and the open inspector next polls automatically
- **THEN** the new complete snapshot removes it from the applicable group and color counts without changing any machine settings.

#### Scenario: One wire cannot be enumerated
- **WHEN** either color's traversal cannot complete within its current work slice or configured retained-memory allowance
- **THEN** the UI does not claim a complete combined inventory or unique total
- **AND** any retained prior snapshot is explicitly stale rather than mixed with new partial counts.

## ADDED Requirements

### Requirement: Native-capacity schemas
Configuration schemas SHALL distinguish actual native field restrictions from configurable resource admission. Generic schema generation SHALL NOT add fixed string, array, section or patch-field capacities absent a native constraint. Rejected updates SHALL retain their existing atomicity and recovery protections.

#### Scenario: Native configuration exceeds former schema maxima
- **WHEN** a valid native target has more than 32 sections or 128 filters/array entries where the engine permits them
- **THEN** complete reads and valid updates work under adequate configured resources, including inspection and generated capability descriptions.

#### Scenario: Target changes while an update waits
- **WHEN** a prepared update pauses and another authorized writer changes the target
- **THEN** commit revalidates the affected current state and authority, recomputes or refuses safely, and never restores a stale whole-target snapshot over the other writer.
