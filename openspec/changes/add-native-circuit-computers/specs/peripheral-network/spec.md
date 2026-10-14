# Peripheral Network

## Purpose

Determine which mod peripherals a computer may call from physical circuit-wire connections while preserving color boundaries and keeping factory signal I/O separate from device discovery.

## ADDED Requirements

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
