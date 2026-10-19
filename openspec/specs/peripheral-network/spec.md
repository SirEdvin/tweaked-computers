# peripheral-network Specification

## Purpose

Determine which mod peripherals a computer may call from physical circuit-wire connections while preserving color boundaries and keeping factory signal I/O separate from device discovery.

## Requirements

### Requirement: Color-preserving physical reachability
Discovery SHALL follow real, same-color wires through this mod's computer-network ports only, within one force and surface. A path MUST NOT switch color, traverse a vanilla entity, cross an input/output/target role or follow a ghost connection.

#### Scenario: Same-color transitive discovery
- **WHEN** a computer reaches a database and then a monitor through red network-port wires
- **THEN** both peripherals are available on the red channel.

#### Scenario: Mixed-color path is not a path
- **WHEN** the only route is computer --red--> database --green--> monitor
- **THEN** the monitor is unavailable from that computer through either channel unless a separate complete same-color path exists.

#### Scenario: Vanilla relay is ignored
- **WHEN** two mod network ports are connected only through an electric pole or ordinary machine
- **THEN** discovery does not cross that entity even if native circuit signals propagate.

### Requirement: Passive discovery ports
Network ports SHALL emit no mod-generated circuit signals and SHALL expose no signal read/write service. Native continuity between wires on the same physical connector SHALL remain acceptable. The mod MUST NOT silently delete player-owned unsupported wires to enforce discovery policy.

#### Scenario: External signals appear on a discovery cable
- **WHEN** a player wires an ordinary signal source to a network port
- **THEN** its signals are not exposed through computer-network APIs and do not alter peripheral reachability by value
- **AND** the UI can explain the unsupported discovery edge without removing it.

### Requirement: Explicit discovery channel and stable identities
Guest discovery SHALL require an explicit red or green channel and return stable opaque peripheral names. Wrappers SHALL retain that channel and device identity, not a mutable label or coordinate. Reaching one device by multiple paths MUST NOT duplicate it within a channel.

#### Scenario: Same peripheral on both channels
- **WHEN** a database is separately reachable through complete red and green paths
- **THEN** each channel can expose the same physical database without connecting the two graphs
- **AND** wrappers remain authorized only through their selected channel.

#### Scenario: Replacement is not identity reuse
- **WHEN** a peripheral is removed and another is placed at its coordinates
- **THEN** an old wrapper cannot control the replacement merely because its position or label matches.

### Requirement: Bounded topology reconciliation and fail-closed calls
Topology changes SHALL be reconciled deterministically within published capacity/latency limits. A peripheral operation MUST fail closed if current reachability cannot be established within its work allowance. A stale cache alone MUST NOT authorize a mutation.

#### Scenario: Wiring changes without a dedicated engine event
- **WHEN** a player or another mod removes a path without a dedicated wire-change notification
- **THEN** subsequent calls cannot use stale cached authority and periodic reconciliation updates discovery/events within the declared supported envelope.

#### Scenario: Unsupported network size
- **WHEN** traversal exceeds a declared node, edge or work limit
- **THEN** the computer receives an explicit pending/limit diagnostic rather than an apparently complete partial device list.

### Requirement: Deterministic shared access
All authorized computers SHALL share a peripheral's committed state. Successful operations SHALL be serialized by synchronized dispatch order, with later successful writes winning for the same value. No implicit exclusive claim or callback-wide transaction SHALL be introduced.

#### Scenario: Two database users
- **WHEN** two authorized computers write the same key in a known dispatch order
- **THEN** all subsequent readers observe the later committed value on every multiplayer peer.

### Requirement: Attachment and detachment notifications
Registered computers SHALL receive channel-qualified attachment/detachment events for published availability changes. Detachment SHALL invalidate affected authority before later guest operations and trigger applicable logic-output cleanup independently of guest handlers.

#### Scenario: Detach handler fails
- **WHEN** a detached peripheral's notification handler raises an error
- **THEN** the connection remains revoked and host-owned output cleanup is not skipped.

### Requirement: Logical displays do not introduce hidden network bridges
A merged monitor SHALL expose one display identity through any wired member in its group. Shared display contents MUST NOT create an unwired path between different member connectors or bridge red and green channels.

#### Scenario: Separate cables touch separate tiles of one display
- **WHEN** two computers reach different tiles of a merged monitor but have no wire path between those tiles
- **THEN** both can address the same shared display
- **AND** neither gains discovery access to peripherals on the other's cable through the framebuffer alone.

### Requirement: Role and force isolation
Factory input/output and configurator target ports SHALL not act as computer-network relays. Access SHALL be revoked on force/surface changes and entity invalidation. Being friendly or allied SHALL not grant same-force program-editing or peripheral authority.

#### Scenario: A factory cable contains another computer
- **WHEN** a logic input or configurator target cable reaches another computer
- **THEN** that cable does not join their computer discovery graphs.

### Requirement: Integrated device wiring targets
A player SHALL connect a computer, database or monitor using a socket visibly belonging to that device. Normal selection and wiring MUST NOT expose an anonymous NETWORK tile or require discovering an invisible separate tile. Hover identity and connector position SHALL identify the actual device; wiring SHALL still use native red/green circuit wires.

#### Scenario: Wire a computer directly to a monitor
- **WHEN** a player selects a red or green wire and connects the visible computer and monitor sockets
- **THEN** the wire attaches at those sockets, the targets are identified as computer and monitor, and discovery exposes the monitor on the chosen channel.

#### Scenario: Select without a wire
- **WHEN** a player selects or opens a single-role device with no wiring tool
- **THEN** the device identity and supported device action are presented instead of an inert helper entity or vanilla combinator configuration dialog.

### Requirement: Explicit multi-role sockets
A logic handler SHALL visibly distinguish input, computer-network and output sockets. A configurator SHALL distinguish computer-network and factory-target sockets. Their locations, symbols and contextual names SHALL agree with the artwork in every rotation. An internal helper MUST NOT be presented as a separately buildable generic network tile.

#### Scenario: Connect all logic roles
- **WHEN** the player connects factory signals to Input, a computer to Network and consumers to Output
- **THEN** the three independent roles remain distinguishable and neither discovery nor native signal continuity bridges them internally.

#### Scenario: Configure without joining discovery
- **WHEN** a target cable reaches a factory machine and another computer
- **THEN** it remains a target-only route and does not join the configurator's computer-network graph.

### Requirement: Wiring compatibility after presentation changes
Changing physical connector presentation SHALL preserve the version-1 discovery/call contracts, red/green separation, unsupported-wire retention, power-independent passive topology and absence of mod-generated network signals. Monitor membership MUST NOT introduce unwired discovery paths.

#### Scenario: Existing program with same-color cable
- **WHEN** an existing supported program discovers or wraps a peripheral after the redesign
- **THEN** its names, channel selection, arguments, return/error behavior and authorization semantics remain compatible.

#### Scenario: Mixed-color and vanilla relay paths
- **WHEN** the only path changes wire color or traverses a vanilla relay
- **THEN** the redesign does not grant discovery access merely because the devices are easier to select.

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
