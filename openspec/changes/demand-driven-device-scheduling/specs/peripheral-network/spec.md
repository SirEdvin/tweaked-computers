# peripheral-network delta

## MODIFIED Requirements

### Requirement: Explicit checked monitor-group selection
An active computer run SHALL be able to select at most one synchronized group using a bounded dense array of exact monitor names and explicit red/green channels. The host SHALL prove every member's current type, logical identity and reachability, deduplicate equal logical identities, and atomically replace the prior selection only after complete validation and capacity admission.

#### Scenario: Same logical display through both colors
- **WHEN** a selection contains the same logical monitor on red and green through valid independent paths
- **THEN** both supplied paths are checked, the logical member occurs once, and red is retained as its canonical binding
- **AND** no electrical or discovery bridge is introduced.

#### Scenario: Invalid replacement
- **WHEN** any selected name is missing, not a monitor, unreachable, over capacity, or cannot be completely checked
- **THEN** a documented typed error is raised and the previous group remains unchanged
- **AND** no successful partial selection is returned.

#### Scenario: Heterogeneous monitor selection
- **WHEN** currently authorized 1×1, 3×6 and 6×6 logical displays with differing resolutions or orientations are selected and their actual summed cells fit the published capacity
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

### Requirement: Computer-rooted radar enrollment
Radar enrollment and rediscovery SHALL originate from placed computers and follow the existing same-color physical reachability policy. Standalone peripherals and remembered native carriers SHALL NOT independently seed radar adoption. Supported intermediate relays SHALL remain traversable, including previously unenrolled native carriers, without allowing color, role, force, surface or hidden-radio bridges.

#### Scenario: Transitive same-color attachment
- **WHEN** a computer reaches a database and then a supported radar through real red network wires
- **THEN** bounded adoption makes the radar discoverable on red without requiring a direct computer-to-radar cable.

#### Scenario: Mixed-color path is not enrollment authority
- **WHEN** the only route is computer --red--> database --green--> radar
- **THEN** the radar is not enrolled or activated through that route
- **AND** a separate complete same-color path is required.

#### Scenario: Standalone component with no computer
- **WHEN** radars are wired to a standalone database, monitor or supported speaker component containing no computer
- **THEN** that component does not seed radar enrollment or recurring radar maintenance
- **AND** adding a computer through a valid physical path later permits normal discovery.

#### Scenario: Previously unenrolled relay chain
- **WHEN** a computer is attached through a same-color chain of supported native radar and speaker connectors that have not yet been enrolled
- **THEN** bounded computer-rooted adoption can discover the full supported chain
- **AND** it does not require pre-registering all native carriers in the world or returning an apparently complete partial inventory.

#### Scenario: Factory ports and unsupported relays remain excluded
- **WHEN** a radar is connected only through a logic input/output socket, a Configurator target socket, an ordinary electric pole, a ghost connection or another unsupported relay
- **THEN** that route neither enrolls the radar as a computer peripheral nor grants modem authority
- **AND** player-owned wires and native factory behavior remain intact.

#### Scenario: Native radio link does not seed adoption
- **WHEN** a locally attached radar has a hidden radar-origin connection to a distant radar component with no valid local computer path
- **THEN** the distant component is not enrolled or activated through that hidden link
- **AND** an independent computer physically connected to the distant component can discover it through its own local path.

#### Scenario: Stopped or unpowered computer remains a physical root
- **WHEN** a valid placed computer is wired to a radar but its program is stopped or faulted, or the native radar is unpowered
- **THEN** the physical attachment is not treated as disconnection merely because execution or native-radar power is unavailable
- **AND** enrollment/metadata discovery preserves the existing passive-topology policy while execution retains normal authority checks and modem operations retain native power checks.

### Requirement: Dashboard method discovery reflects optional charts
Dashboard method enumeration and wrapping SHALL expose the exact base method set from its companion API, adding only the specified chart methods when the compatible optional library is enabled. Dependency presence SHALL NOT bypass current identity, force, surface or physical-path checks.

#### Scenario: Query without the chart dependency
- **WHEN** a computer discovers and wraps a dashboard without factorio-charts
- **THEN** it can configure base controls and subscribe to buttons but cannot discover or invoke a stub chart method.

#### Scenario: Retained symbolic method after dependency removal
- **WHEN** a saved Console binding refers to a chart method after the library is removed
- **THEN** it fails safely as unavailable rather than retargeting another method or invoking a stale native handle
- **AND** ordinary base methods and unrelated authentic bindings remain valid under their existing authority rules.

## ADDED Requirements

### Requirement: Demand-owned topology and output authority
Topology notifications, native-carrier adoption and output-owner safety SHALL operate from explicit interested bindings, pending discoveries and owned resources rather than discovering work through whole-registry tick walks. Passive discovery and all operation-boundary live proofs SHALL remain correct even when no background observer exists.

#### Scenario: Unused connected devices
- **WHEN** idle custom devices exist with no topology subscriber, active input watcher, output owner, pending discovery or open UI
- **THEN** they do not acquire per-tick topology/owner work; an explicit discovery call still returns a complete authorized result or existing pending/error status.

#### Scenario: Silent wire edit
- **WHEN** a path changes without a usable native event
- **THEN** interested attach/detach observations refresh within the existing topology envelope, active subscriptions revalidate their own selected binding and active output owners meet the existing fail-safe deadline; direct calls never use stale positive authority.

#### Scenario: Output owner membership
- **WHEN** a logic output is written, overwritten or cleared
- **THEN** the current output owner receives the necessary fail-safe checks and obsolete membership is retired; inactive logic devices are not visited just to find owners.

#### Scenario: Owner proof cannot complete
- **WHEN** a retained output owner loses its path or its proof is refused
- **THEN** its still-owned output is cleared under existing safety semantics independently of callbacks; another later writer is not cleared by the old owner.

#### Scenario: Demand-driven native adoption
- **WHEN** a valid computer-rooted discovery or interested topology observation encounters a supported native carrier
- **THEN** bounded adoption progresses with complete-or-pending semantics, while standalone components and dormant radars do not seed a periodic world scan.

### Requirement: Power-independent custom peripheral metadata and services
Custom composite peripherals SHALL remain usable without electricity; their methods MUST NOT return E_UNPOWERED for missing electrical supply. Existing metadata shapes SHALL remain compatible: powered is true for a valid custom endpoint and native availability for radar/speaker endpoints is sampled at the requested read. Reachability, identity, scope and non-power diagnostics remain separate checks.

#### Scenario: Custom device with no electrical supply
- **WHEN** an authorized caller describes or invokes a custom peripheral outside electrical coverage
- **THEN** metadata retains its existing fields and methods work without an electrical helper, subject to normal non-power validation.

#### Scenario: Native availability at use
- **WHEN** a radar or speaker loses supply between description and an active call
- **THEN** the call rechecks native availability and refuses with E_UNPOWERED before effects; prior metadata cannot authorize it.

#### Scenario: Native endpoint idle
- **WHEN** a remembered radar or speaker receives no operation, metadata request, transmission eligibility evaluation or explicit UI interaction
- **THEN** the mod performs no proactive power polling of that endpoint; native simulation continues independently.
