# Peripheral network interaction delta

Baseline: corresponding capability in `add-native-circuit-computers`; same-color physical traversal, no vanilla relays, passive continuity, stable identities, bounded admission and fail-closed authorization remain binding.

## ADDED Requirements

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
