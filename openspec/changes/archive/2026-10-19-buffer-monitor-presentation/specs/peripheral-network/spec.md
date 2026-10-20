# Peripheral monitor-group delta

Baseline: `add-native-circuit-computers/specs/peripheral-network`, including current-authority checks, explicit channels and serialized shared access. Canonical specs are not yet materialized. This adds selection of presentation cohorts, not a different discovery protocol or write transaction. Exact signatures are in [the Lua companion](../monitor-display/lua-api.md).

## ADDED Requirements

### Requirement: Explicit checked monitor-group selection
An active computer run SHALL be able to select at most one synchronized group using a bounded dense array of exact monitor names and explicit red/green channels. The host SHALL prove every member's current type, logical identity and reachability, deduplicate equal logical identities, and atomically replace the prior selection only after complete validation and capacity admission.

#### Scenario: Same logical display through both colors
- **WHEN** a selection contains the same logical monitor on red and green through valid independent paths
- **THEN** both supplied paths are checked, the logical member occurs once, and red is retained as its canonical binding
- **AND** no electrical or discovery bridge is introduced.

#### Scenario: Invalid replacement
- **WHEN** any selected name is missing, not a monitor, unpowered, unreachable, over capacity, or cannot be completely checked
- **THEN** a documented typed error is raised and the previous group remains unchanged
- **AND** no successful partial selection is returned.

#### Scenario: Heterogeneous monitor selection
- **WHEN** currently authorized powered 1×1, 3×6 and 6×6 logical displays with differing resolutions or orientations are selected and their actual summed cells fit the published capacity
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

### Requirement: Group selection preserves shared access
Selecting a group SHALL affect presentation only. It SHALL NOT grant new discovery or writing authority, make a callback transactional, or exclude other authorized writers. A logical monitor SHALL belong to at most one explicitly selected presentation group; a conflicting group selection SHALL fail without changing either selection.

#### Scenario: Another writer changes a grouped monitor
- **WHEN** a different computer has a valid independent network path to a grouped monitor
- **THEN** its ordinary terminal calls still succeed in synchronized dispatch order
- **AND** successful mutations participate in that monitor's group round without granting access to other group members.

#### Scenario: Competing group registration
- **WHEN** another run attempts to include a monitor already selected by a different run
- **THEN** registration fails with E_BUSY and both existing monitor content and the original selection remain intact.

### Requirement: Observable nonblocking group status
The group API SHALL return defensive plain-data status, canonical member bindings, the last presented sequence/tick and an optional typed diagnostic. It SHALL distinguish no selection, waiting for participation, preparation/backpressure and temporary blockage. Status readback SHALL NOT wait for rendering or expose native objects, mutable host tables or saved guest facades.

#### Scenario: A selected member has not updated
- **WHEN** a program queries status while one group member has not participated in the next round
- **THEN** status reports waiting and the last presented sequence remains unchanged.

#### Scenario: Caller mutates its returned snapshot
- **WHEN** a program modifies a returned member array or diagnostic table
- **THEN** neither group membership nor publication state changes.

### Requirement: Run-bound ownership and revocation
Group configuration SHALL bind to the selecting computer run and exact member identities. Explicit clearing, run retirement, definitive path revocation or identity removal SHALL cancel the entire unpublished cohort and release the selection without clearing shared models or already presented images. Temporary proof deferral SHALL block group publication rather than silently authorize it or partially release members.

#### Scenario: Cable removed before commit
- **WHEN** a selected path is definitively revoked while replacement frames are hidden
- **THEN** that cohort never partially publishes and the selection is released with an observable reason
- **AND** retained accepted model changes can subsequently present through ordinary automatic buffering.

#### Scenario: Same coordinate gets a new monitor
- **WHEN** an addressed logical identity is removed and a new device appears at its old position
- **THEN** the old selection cannot retarget to the replacement.

#### Scenario: Save and load without retirement
- **WHEN** a selected run and pending group survive an ordinary cold save/load
- **THEN** ownership and identity bindings remain the same without re-running registration or guest start handlers.
