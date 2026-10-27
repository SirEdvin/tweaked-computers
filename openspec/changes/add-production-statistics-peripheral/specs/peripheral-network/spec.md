# Peripheral Network Spec Delta

## MODIFIED Requirements

### Requirement: Integrated device wiring targets
A player SHALL connect a computer, database, monitor, Production Statistics device, supported radar modem or vanilla speaker using a socket visibly belonging to that device. Normal selection/wiring MUST NOT expose an anonymous NETWORK tile or require an invisible separate tile. Hover identity and connector position SHALL identify the device; wiring SHALL use native red/green wires. Native radar/speaker attachment SHALL use existing connectors and preserve native opening behavior.

#### Scenario: Wire a computer directly to a monitor
- **WHEN** a player selects a red or green wire and connects the visible computer and monitor sockets
- **THEN** the wire attaches at those sockets, the targets are identified as computer and monitor, and discovery exposes the monitor on the chosen channel.

#### Scenario: Select without a wire
- **WHEN** a player selects or opens a mod-authored single-role device with no wiring tool
- **THEN** the device identity and supported device action are presented instead of an inert helper entity or vanilla combinator configuration dialog.

#### Scenario: Wire an existing vanilla radar
- **WHEN** a player connects a computer network socket to a vanilla radar's existing circuit connector
- **THEN** the radar becomes the local modem without an adapter item, separate helper socket or replacement of the radar entity.

#### Scenario: Open a registered speaker
- **WHEN** a player opens a vanilla speaker that is registered as a peripheral
- **THEN** its ordinary speaker configuration GUI opens without a replacement inspector, helper socket or change to native interaction.

#### Scenario: Wire a Production Statistics device
- **WHEN** a player wires a computer to the statistics device's visible Network socket
- **THEN** discovery exposes type `production_statistics` only through the selected same-color, same-force, same-surface physical path
- **AND** the device is a passive Network relay without exposing factory signals or bridging red and green.
