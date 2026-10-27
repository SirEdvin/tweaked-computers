# Peripheral Network Spec Delta

## MODIFIED Requirements

### Requirement: Integrated device wiring targets
A player SHALL connect a computer, database, monitor, dashboard, supported radar modem or vanilla speaker using a socket visibly belonging to that device. Normal selection/wiring MUST NOT expose an anonymous NETWORK tile or require an invisible separate tile. Hover identity and connector position SHALL identify the device; wiring SHALL use native red/green wires. Native radar/speaker attachment SHALL use existing connectors and preserve native opening behavior.

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

#### Scenario: Discover a dashboard on both colors
- **WHEN** independent valid red and green paths reach a dashboard
- **THEN** both expose the same opaque physical identity with type `dashboard`, with separately authorized wrappers and shared content
- **AND** neither its UI nor its button subscriptions bridge those colors or make remote peripherals discoverable.

## ADDED Requirements

### Requirement: Dashboard method discovery reflects optional charts
Dashboard method enumeration and wrapping SHALL expose the exact base method set from its companion API, adding only the specified chart methods when the compatible optional library is enabled. Dependency presence SHALL NOT bypass current identity, force, surface, power or physical-path checks.

#### Scenario: Query without the chart dependency
- **WHEN** a computer discovers and wraps a dashboard without factorio-charts
- **THEN** it can configure base controls and subscribe to buttons but cannot discover or invoke a stub chart method.

#### Scenario: Retained symbolic method after dependency removal
- **WHEN** a saved Console binding refers to a chart method after the library is removed
- **THEN** it fails safely as unavailable rather than retargeting another method or invoking a stale native handle
- **AND** ordinary base methods and unrelated authentic bindings remain valid under their existing authority rules.
