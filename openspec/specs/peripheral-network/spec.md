# peripheral-network Specification

## Purpose

Determine which mod peripherals a computer may call from physical circuit-wire connections while preserving color boundaries and keeping factory signal I/O separate from device discovery.

## Requirements

### Requirement: Color-preserving physical reachability
Discovery SHALL follow real, same-color physical wires through this mod's computer-network ports, supported native radar modem connectors and registered vanilla programmable-speaker connectors only, within one force and surface. A path MUST NOT switch color, traverse another unsupported vanilla entity, cross an input/output/target role, follow a ghost connection or follow a radar-origin hidden wire. Native circuit-network identity MUST NOT substitute for a physical discovery path.

#### Scenario: Same-color transitive discovery
- **WHEN** a computer reaches a database and then a monitor through red network-port wires
- **THEN** both peripherals are available on the red channel.

#### Scenario: Mixed-color path is not a path
- **WHEN** the only route is computer --red--> database --green--> monitor
- **THEN** the monitor is unavailable from that computer through either channel unless a separate complete same-color path exists.

#### Scenario: Vanilla relay is ignored
- **WHEN** two mod network ports are connected only through an electric pole or ordinary unsupported machine
- **THEN** discovery does not cross that entity even if native circuit signals propagate.

#### Scenario: Local radar physical relay
- **WHEN** a computer and database connect by separate real red wires to the same supported radar connector
- **THEN** the computer discovers the radar modem and the database on red without discovering devices wired only to the radar's green connector.

#### Scenario: Hidden native radar link
- **WHEN** local and distant radars are joined by Factorio's radar-origin hidden circuit wires and the distant radar is wired to a database
- **THEN** neither the distant radar nor the database becomes locally discoverable through those hidden wires
- **AND** the same exclusion applies when revalidating an existing path witness.

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

#### Scenario: Speaker relay preserves radar-origin isolation
- **WHEN** a computer reaches a local supported radar through a registered speaker, and a distant radar has a database attached only through its native hidden radio link
- **THEN** local physical discovery and saved-witness validation exclude that distant radar and database
- **AND** local physical radar/speaker relays remain supported on the selected color.

### Requirement: Passive discovery ports
Network ports SHALL emit no mod-generated signals and expose no signal read/write service. Native continuity on the same physical connector SHALL remain acceptable. Registered speakers SHALL retain circuit playback independently of peripheral calls; supported radars SHALL retain native circuit transmission independently of modem traffic. Native signal continuity MUST NOT grant discovery authority. The mod MUST NOT delete player-owned unsupported wires to enforce discovery policy.

#### Scenario: External signals appear on a discovery cable
- **WHEN** a player wires an ordinary signal source to a network port
- **THEN** its signals are not exposed through computer-network APIs and do not alter peripheral reachability by value
- **AND** the UI can explain the unsupported discovery edge without removing it.

#### Scenario: Radar carries native factory signals
- **WHEN** Factorio transmits circuit signals between two same-surface radars
- **THEN** that native behavior remains intact without encoding modem packets into signals or making remote peripherals discoverable.

#### Scenario: Native circuit-triggered speaker
- **WHEN** circuit signals reach a registered speaker's native connector and satisfy its configured condition
- **THEN** its normal circuit playback remains functional without mod-generated trigger signals
- **AND** those values do not authorize paths across a color or unsupported entity.

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

#### Scenario: Unrelated native adoption is pending
- **WHEN** discovery reports `E_NETWORK_PENDING` while a newly wired native carrier awaits enrollment
- **THEN** the last complete attachment observation is retained without spurious detach/attach notifications or revoking unrelated output whose selected witness remains live
- **AND** current calls still require a complete live proof, output safety checks still clear genuinely lost authority, and completed enrollment publishes only the actual attachment change.

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
A player SHALL connect a computer, database, monitor, Production Statistics device, dashboard, supported radar modem or vanilla speaker using a socket visibly belonging to that device. Normal selection/wiring MUST NOT expose an anonymous NETWORK tile or require an invisible separate tile. Hover identity and connector position SHALL identify the device; wiring SHALL use native red/green wires. Native radar/speaker attachment SHALL use existing connectors and preserve native opening behavior.

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

#### Scenario: Discover a dashboard on both colors
- **WHEN** independent valid red and green paths reach a dashboard
- **THEN** both expose the same opaque physical identity with type `dashboard`, with separately authorized wrappers and shared content
- **AND** neither its UI nor its button subscriptions bridge those colors or make remote peripherals discoverable.

### Requirement: Explicit multi-role sockets
A logic handler SHALL visibly distinguish input, computer-network and output sockets. A configurator SHALL distinguish computer-network and factory-target sockets. Their locations, symbols and contextual names SHALL agree with the artwork in every rotation. An internal helper MUST NOT be presented as a separately buildable generic network tile.

#### Scenario: Connect all logic roles
- **WHEN** the player connects factory signals to Input, a computer to Network and consumers to Output
- **THEN** the three independent roles remain distinguishable and neither discovery nor native signal continuity bridges them internally.

#### Scenario: Configure without joining discovery
- **WHEN** a target cable reaches a factory machine and another computer
- **THEN** it remains a target-only route and does not join the configurator's computer-network graph.

### Requirement: Wiring compatibility after presentation changes
Changing physical connector presentation SHALL preserve the version-1 discovery/call contracts, red/green separation, unsupported-wire retention, power-independent passive topology and absence of mod-generated network signals. Monitor membership MUST NOT introduce unwired discovery paths. Explicit native-speaker support SHALL NOT authorize other unsupported vanilla relays.

#### Scenario: Existing program with same-color cable
- **WHEN** an existing supported program discovers or wraps a peripheral after the redesign
- **THEN** its names, channel selection, arguments, return/error behavior and authorization semantics remain compatible.

#### Scenario: Mixed-color and vanilla relay paths
- **WHEN** the only path changes wire color or traverses an unsupported vanilla relay
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

### Requirement: Wireless transport is not discovery authority
Receiving a modem message SHALL NOT reveal, wrap or authorize peripherals attached to the sender's radar. Neither modem channels nor native radar signal links SHALL join red/green discovery graphs or cross-surface discovery scopes. Message data containing an opaque peripheral name SHALL remain data, not a capability.

#### Scenario: Remote database name in a packet
- **WHEN** a computer receives a message containing the name of a database wired only to a remote radar
- **THEN** local discovery still excludes that database and wrapping/calling it fails without a separate valid local physical path.

#### Scenario: Interplanetary message receipt
- **WHEN** an advanced modem receives a message from another surface
- **THEN** only its locally connected computer receives the data and no remote physical vertices become accessible.

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
- **WHEN** a valid placed computer is wired to a radar but its program is stopped or faulted, or the computer or radar is unpowered
- **THEN** the physical attachment is not treated as disconnection merely because execution or power is unavailable
- **AND** enrollment/metadata discovery preserves the existing passive-topology policy while execution and modem operations retain their normal authority/power checks.

### Requirement: Radar detachment cannot sustain its own discovery work
A component that loses its last valid computer-rooted path SHALL stop sustaining radar work. Existing per-call authority proofs SHALL remain fail-closed; stale observations SHALL NOT authorize modem operations or radio delivery. Bounded attachment/detachment bookkeeping SHALL preserve existing notification and latency contracts without turning dormant records into a polling source.

#### Scenario: Last computer is removed
- **WHEN** the sole computer is removed while the remaining radars and supported peripherals stay wired together
- **THEN** the residual component does not become an adoption root or sustain recurring radar maintenance
- **AND** remembered radar identity/channel data remains dormant and recoverable.

#### Scenario: Cable cut before an operation
- **WHEN** a previously discovered radar loses the caller's valid path before its next modem operation
- **THEN** the operation fails under the existing live authority policy even if an earlier topology observation still names the radar
- **AND** finite detachment notifications do not make that stale observation a fresh adoption root.

#### Scenario: Another valid path survives
- **WHEN** one computer or color loses its path while another computer or complete same-color path still reaches the same radar
- **THEN** valid callers retain access to the same physical identity and shared channels
- **AND** invalid callers and colors gain no authority from the surviving path.

#### Scenario: Discovery proof is incomplete
- **WHEN** a computer-rooted traversal reaches an existing node, edge, work or identity capacity boundary, or topology changes invalidate its proof
- **THEN** it preserves accepted state and reports the existing pending/limit/capacity outcome rather than successful partial discovery or stale authority
- **AND** it does not fall back to a world scan or a sweep over dormant radars.

### Requirement: Dashboard method discovery reflects optional charts
Dashboard method enumeration and wrapping SHALL expose the exact base method set from its companion API, adding only the specified chart methods when the compatible optional library is enabled. Dependency presence SHALL NOT bypass current identity, force, surface, power or physical-path checks.

#### Scenario: Query without the chart dependency
- **WHEN** a computer discovers and wraps a dashboard without factorio-charts
- **THEN** it can configure base controls and subscribe to buttons but cannot discover or invoke a stub chart method.

#### Scenario: Retained symbolic method after dependency removal
- **WHEN** a saved Console binding refers to a chart method after the library is removed
- **THEN** it fails safely as unavailable rather than retargeting another method or invoking a stale native handle
- **AND** ordinary base methods and unrelated authentic bindings remain valid under their existing authority rules.
