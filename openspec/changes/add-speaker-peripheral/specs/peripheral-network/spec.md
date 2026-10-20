# Spec Delta

## MODIFIED Requirements

### Requirement: Color-preserving physical reachability
Discovery SHALL follow real, same-color wires through this mod's computer-network ports and registered vanilla programmable-speaker connectors only, within one force and surface. A path MUST NOT switch color, traverse another unsupported vanilla entity, cross an input/output/target role or follow a ghost connection. Native circuit-network identity MUST NOT substitute for a physical discovery path.

#### Scenario: Same-color transitive discovery
- **WHEN** a computer reaches a database and then a monitor through red network-port wires
- **THEN** both peripherals are available on the red channel.

#### Scenario: Mixed-color path is not a path
- **WHEN** the only route is computer --red--> database --green--> monitor
- **THEN** the monitor is unavailable from that computer through either channel unless a separate complete same-color path exists.

#### Scenario: Vanilla relay is ignored
- **WHEN** two mod network ports are connected only through an electric pole or ordinary unsupported machine
- **THEN** discovery does not cross that entity even if native circuit signals propagate.

#### Scenario: Speaker relays its physical color
- **WHEN** a computer and monitor connect by separate real red wires to the same supported speaker connector
- **THEN** discovery exposes the speaker and monitor on red
- **AND** a device connected only to that speaker's green connector remains unreachable on red.

#### Scenario: Speaker does not authorize a pole relay
- **WHEN** a computer reaches a speaker directly but a database is reachable from that speaker only through an electric pole
- **THEN** the speaker is discoverable but the database is not authorized through the pole.

#### Scenario: Speaker on a factory-only port
- **WHEN** a speaker is reachable only from a Configurator target port or logic input/output port
- **THEN** it can participate in that native factory network without becoming a directly discoverable speaker peripheral through that role.

### Requirement: Passive discovery ports
Network ports SHALL emit no mod-generated circuit signals and SHALL expose no signal read/write service. Native continuity between wires on the same physical connector SHALL remain acceptable. Registered speakers SHALL retain native circuit playback independently of peripheral calls; native signal continuity MUST NOT grant discovery authority. The mod MUST NOT silently delete player-owned unsupported wires to enforce discovery policy.

#### Scenario: External signals appear on a discovery cable
- **WHEN** a player wires an ordinary signal source to a network port
- **THEN** its signals are not exposed through computer-network APIs and do not alter peripheral reachability by value
- **AND** the UI can explain the unsupported discovery edge without removing it.

#### Scenario: Native circuit-triggered speaker
- **WHEN** circuit signals reach a registered speaker's native connector and satisfy its configured condition
- **THEN** its normal circuit playback remains functional without mod-generated trigger signals
- **AND** those values do not authorize paths across a color or unsupported entity.

### Requirement: Integrated device wiring targets
A player SHALL connect a computer, database, monitor or supported vanilla speaker using a socket visibly belonging to that device. Normal selection and wiring MUST NOT expose an anonymous NETWORK tile or require discovering an invisible separate tile. Hover identity and connector position SHALL identify the actual device; wiring SHALL still use native red/green circuit wires. Speaker attachment SHALL use its existing native connectors and preserve its native opening behavior.

#### Scenario: Wire a computer directly to a monitor
- **WHEN** a player selects a red or green wire and connects the visible computer and monitor sockets
- **THEN** the wire attaches at those sockets, the targets are identified as computer and monitor, and discovery exposes the monitor on the chosen channel.

#### Scenario: Select without a wire
- **WHEN** a player selects or opens a mod-authored single-role device with no wiring tool
- **THEN** the device identity and supported device action are presented instead of an inert helper entity or vanilla combinator configuration dialog.

#### Scenario: Open a registered speaker
- **WHEN** a player opens a vanilla speaker that is registered as a peripheral
- **THEN** its ordinary speaker configuration GUI opens without a replacement inspector, helper socket or change to native interaction.

### Requirement: Wiring compatibility after presentation changes
Changing physical connector presentation SHALL preserve the version-1 discovery/call contracts, red/green separation, unsupported-wire retention, power-independent passive topology and absence of mod-generated network signals. Monitor membership MUST NOT introduce unwired discovery paths. Explicit native-speaker support SHALL NOT authorize other unsupported vanilla relays.

#### Scenario: Existing program with same-color cable
- **WHEN** an existing supported program discovers or wraps a peripheral after the redesign
- **THEN** its names, channel selection, arguments, return/error behavior and authorization semantics remain compatible.

#### Scenario: Mixed-color and vanilla relay paths
- **WHEN** the only path changes wire color or traverses an unsupported vanilla relay
- **THEN** the redesign does not grant discovery access merely because the devices are easier to select.
