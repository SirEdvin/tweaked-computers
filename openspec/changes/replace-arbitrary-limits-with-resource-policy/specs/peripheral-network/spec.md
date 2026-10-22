## MODIFIED Requirements

### Requirement: Bounded topology reconciliation and fail-closed calls
Topology changes SHALL be reconciled deterministically under configured work/storage budgets without node/edge cardinality ceilings. A peripheral operation SHALL defer while current reachability proof is incomplete, or refuse recoverably if retained resources cannot admit it. It MUST fail closed until proof completes. A stale cache alone MUST NOT authorize a mutation.

#### Scenario: Wiring changes without a dedicated engine event
- **WHEN** a player or another mod removes a path without a dedicated wire-change notification
- **THEN** subsequent calls cannot use stale cached authority and periodic reconciliation updates discovery/events within the declared supported envelope.

#### Scenario: Unsupported network size
- **WHEN** traversal crosses the former node/edge ceilings or exhausts a work slice
- **THEN** traversal retains incremental progress and reports pending until it can publish a complete inventory, never an apparently complete partial list.

### Requirement: Explicit checked monitor-group selection
An active computer run SHALL be able to select named synchronized groups using dense arrays of exact monitor names and explicit red/green channels. The host SHALL prove every member's current type, logical identity and reachability, deduplicate equal logical identities, and atomically replace the prior selection for the specified group key only after complete validation and capacity admission.

#### Scenario: Same logical display through both colors
- **WHEN** a selection contains the same logical monitor on red and green through valid independent paths
- **THEN** both supplied paths are checked, the logical member occurs once, and red is retained as its canonical binding
- **AND** no electrical or discovery bridge is introduced.

#### Scenario: Invalid replacement
- **WHEN** any selected name is missing, not a monitor, unpowered, unreachable, over capacity, or cannot be completely checked
- **THEN** a documented typed error is raised and the previous group remains unchanged
- **AND** no successful partial selection is returned.

#### Scenario: Heterogeneous monitor selection
- **WHEN** currently authorized powered 1×1, 3×6 and 6×6 logical displays with differing resolutions or orientations are selected and their actual summed cells fit configured aggregate resource capacity
- **THEN** registration succeeds without an equal-size or square-screen condition
- **AND** each exact logical identity/path is retained while one shared presentation barrier covers all members.

#### Scenario: Capacity is based on actual character grids
- **WHEN** selected display shapes/scales change the sum of their character cells
- **THEN** admission uses each member's actual grid rather than tile area alone or a padded 6×6 allocation
- **AND** a capacity rejection preserves the prior selection without rejecting a supported individual shape merely for being nonsquare.

#### Scenario: Pending topology under publication demand
- **WHEN** selected-path proof is pending while large native publications request maintenance headroom
- **THEN** topology initialization retains paid incremental progress and receives baseline-service opportunities between boosted reservations
- **AND** incomplete proof still refuses group admission/publication rather than treating a partial inventory as authority.

## ADDED Requirements

### Requirement: No fixed discovery result or group count
Discovery results and synchronization references, members and group keys SHALL have no independent mod count ceilings. Existing no-key group calls SHALL continue addressing the default group. A logical display SHALL remain in at most one selected group because overlapping publication barriers conflict, not because of a resource quota.

#### Scenario: Large discovery and separate groups
- **WHEN** a network has more than 256 vertices or a caller selects more than four monitors or two disjoint named groups within configured resources
- **THEN** complete discovery and both group selections succeed without a fixed record-count refusal
- **AND** legacy no-key selection still replaces only the default group.

#### Scenario: Authority changes during incremental proof
- **WHEN** a path changes while discovery or selection preparation spans ticks
- **THEN** invalidated evidence is revalidated before access/publication; no old proof grants authority to a disconnected or replacement entity.
