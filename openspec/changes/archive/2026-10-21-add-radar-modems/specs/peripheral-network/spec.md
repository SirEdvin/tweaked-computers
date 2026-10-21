# Spec Delta

## MODIFIED Requirements

### Requirement: Color-preserving physical reachability
Discovery SHALL follow real, same-color physical wires through this mod's computer-network ports and supported native radar modem connectors only, within one force and surface. A path MUST NOT switch color, traverse any other vanilla entity, cross an input/output/target role, follow a ghost connection, or follow a radar-origin hidden wire. Native circuit-network identity MUST NOT substitute for a physical discovery path.

#### Scenario: Same-color transitive discovery
- **WHEN** a computer reaches a database and then a monitor through red network-port wires
- **THEN** both peripherals are available on the red channel.

#### Scenario: Mixed-color path is not a path
- **WHEN** the only route is computer --red--> database --green--> monitor
- **THEN** the monitor is unavailable from that computer through either channel unless a separate complete same-color path exists.

#### Scenario: Vanilla relay is ignored
- **WHEN** two mod network ports are connected only through an electric pole or ordinary machine
- **THEN** discovery does not cross that entity even if native circuit signals propagate.

#### Scenario: Local radar physical relay
- **WHEN** a computer and database connect by separate real red wires to the same supported radar connector
- **THEN** the computer discovers the radar modem and the database on red without discovering devices wired only to the radar's green connector.

#### Scenario: Hidden native radar link
- **WHEN** local and distant radars are joined by Factorio's radar-origin hidden circuit wires and the distant radar is wired to a database
- **THEN** neither the distant radar nor the database becomes locally discoverable through those hidden wires
- **AND** the same exclusion applies when revalidating an existing path witness.

### Requirement: Passive discovery ports
Network ports SHALL emit no mod-generated circuit signals and SHALL expose no signal read/write service. Native continuity between wires on the same physical connector SHALL remain acceptable. Supported radars SHALL retain their native circuit transmission independently of modem traffic; native signal continuity MUST NOT grant discovery authority. The mod MUST NOT silently delete player-owned unsupported wires to enforce discovery policy.

#### Scenario: External signals appear on a discovery cable
- **WHEN** a player wires an ordinary signal source to a network port
- **THEN** its signals are not exposed through computer-network APIs and do not alter peripheral reachability by value
- **AND** the UI can explain the unsupported discovery edge without removing it.

#### Scenario: Radar carries native factory signals
- **WHEN** Factorio transmits circuit signals between two same-surface radars
- **THEN** that native behavior remains intact without encoding modem packets into signals or making remote peripherals discoverable.

### Requirement: Integrated device wiring targets
A player SHALL connect a computer, database, monitor or supported radar modem using a socket visibly belonging to that device. Normal selection and wiring MUST NOT expose an anonymous NETWORK tile or require discovering an invisible separate tile. Hover identity and connector position SHALL identify the actual device; wiring SHALL still use native red/green circuit wires. Vanilla radar attachment SHALL use its existing native connectors.

#### Scenario: Wire a computer directly to a monitor
- **WHEN** a player selects a red or green wire and connects the visible computer and monitor sockets
- **THEN** the wire attaches at those sockets, the targets are identified as computer and monitor, and discovery exposes the monitor on the chosen channel.

#### Scenario: Select without a wire
- **WHEN** a player selects or opens a single-role device with no wiring tool
- **THEN** the device identity and supported device action are presented instead of an inert helper entity or vanilla combinator configuration dialog.

#### Scenario: Wire an existing vanilla radar
- **WHEN** a player connects a computer network socket to a vanilla radar's existing circuit connector
- **THEN** the radar becomes the local modem without an adapter item, separate helper socket or replacement of the radar entity.

## ADDED Requirements

### Requirement: Wireless transport is not discovery authority
Receiving a modem message SHALL NOT reveal, wrap or authorize peripherals attached to the sender's radar. Neither modem channels nor native radar signal links SHALL join red/green discovery graphs or cross-surface discovery scopes. Message data containing an opaque peripheral name SHALL remain data, not a capability.

#### Scenario: Remote database name in a packet
- **WHEN** a computer receives a message containing the name of a database wired only to a remote radar
- **THEN** local discovery still excludes that database and wrapping/calling it fails without a separate valid local physical path.

#### Scenario: Interplanetary message receipt
- **WHEN** an advanced modem receives a message from another surface
- **THEN** only its locally connected computer receives the data and no remote physical vertices become accessible.
