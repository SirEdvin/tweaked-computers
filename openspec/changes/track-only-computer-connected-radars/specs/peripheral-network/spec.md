# Peripheral network spec delta

## ADDED Requirements

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
