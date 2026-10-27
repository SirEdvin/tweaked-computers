# Radar modem spec delta

## MODIFIED Requirements

### Requirement: Native radar modem identity
The vanilla `radar` and optional advanced radar SHALL expose peripheral type `modem` through explicit local red/green discovery. A radar SHALL be enrolled only through a valid computer-rooted physical path. Once enrolled, its opaque identity SHALL remain stable across ordinary saves, both wire colors and same-entity, same-scope disconnection/reconnection. Native radar functions SHALL remain intact, and metadata SHALL identify the tier without exposing native objects.

#### Scenario: Attach a vanilla radar
- **WHEN** a powered computer is connected directly to an existing vanilla radar with a red circuit wire
- **THEN** red discovery exposes a `modem` with the radar's actual position, footprint, quality and power availability
- **AND** its normal scanning, native circuit behavior and opening interaction are unchanged.

#### Scenario: One physical radar on both colors
- **WHEN** the same radar is reachable through independent red and green paths
- **THEN** both paths expose the same opaque name while each wrapper retains its selected wire.

#### Scenario: Unsupported radar-like entity
- **WHEN** another mod adds a different radar prototype
- **THEN** it is not automatically treated as a modem merely because its native type is radar.

#### Scenario: Placement alone does not enroll a radar
- **WHEN** a supported radar is built, cloned or revived without a valid physical path from a computer
- **THEN** the event does not allocate a modem identity or enroll that radar in recurring mod work
- **AND** later wiring it to a valid computer network permits enrollment without rebuilding it.

### Requirement: Durable transport state without replay
Ordinary cold save/load SHALL preserve radar identities, open channels, registered handlers, admitted event order and spent same-tick transport credits without re-transmitting packets or replaying startup. This includes dormant radar identity/channel data without restarting recurring work for it. Mining, replacement, cloning and blueprint placement SHALL NOT transfer open channels or message queues. Radar force/surface reassignment SHALL revoke old authority and reset channels before participation in the new scope.

#### Scenario: Reload with queued communication
- **WHEN** a save with open channels and undelivered modem events is loaded in a separate engine process
- **THEN** each retained event is dispatched once in its existing order, and no startup or transmit effect is repeated.

#### Scenario: Replace or clone a configured radar
- **WHEN** a radar with open channels is mined/replaced, cloned or rebuilt from a blueprint
- **THEN** the new entity has a new identity and an empty channel set when it is enrolled, and old wrappers cannot retarget to it
- **AND** an unconnected replacement or clone remains unenrolled until a computer-rooted path exists.

#### Scenario: Scope change
- **WHEN** a radar changes force or moves to a different surface
- **THEN** its old local bindings are invalidated before further calls and its previously opened channels are cleared before participation in the new scope.

#### Scenario: Ordinary reload preserves dormancy
- **WHEN** an updated save containing disconnected remembered radars is cold-loaded
- **THEN** their saved identities and channels remain intact
- **AND** from the first ordinary tick they do not reenter recurring radar work or a dormant-radar polling sweep.

## ADDED Requirements

### Requirement: Disconnected radars incur no recurring mod work
A radar without a valid computer-rooted physical path SHALL incur no recurring per-radar mod work. Dormant data SHALL NOT be polled, enumerated as radio candidates, or visited by generic ticking sweeps. Discovery work SHALL originate at computers, not disconnected radar components. One-time migration, targeted lifecycle events and bounded detachment bookkeeping are distinct from recurring polling.

#### Scenario: Factory with no computers
- **WHEN** a factory contains many supported radars but no computers
- **THEN** ordinary ticks perform no per-radar mod availability checks, adoption scans or generic maintenance visits
- **AND** increasing the disconnected-radar count does not introduce proportional mod tick work.

#### Scenario: Unrelated radars beside a working computer network
- **WHEN** a working computer network is held fixed while additional disconnected radars are placed or retained as dormant records
- **THEN** recurring radar work remains confined to valid computer-rooted paths
- **AND** transmitting through the working network does not enumerate dormant records as potential receivers.

#### Scenario: Stale saved observations do not restart polling
- **WHEN** the last qualifying cable is removed and the game is saved before a previous attachment observation has been retired
- **THEN** loading that save does not restart per-radar power or lifecycle polling for the disconnected component
- **AND** subsequent use fails closed while any finite detachment notification work completes without replaying packets.

#### Scenario: Native radar simulation is unchanged
- **WHEN** an unconnected radar is not integrated into a computer network
- **THEN** its native scanning, power consumption, circuit transmission and player interactions continue normally
- **AND** the no-recurring-work guarantee applies to this mod, not to Factorio's own entity simulation.

### Requirement: Dormant modem state is recoverable without polling
Losing the last valid computer connection SHALL preserve an enrolled radar's identity and shared channels as dormant data, without recurring work. Reconnecting the same entity in the same scope SHALL restore access to that state. Dormancy SHALL NOT grant authority, receive or buffer traffic, or recall accepted queued events. Destruction and scope changes SHALL retain existing identity and channel-reset protections.

#### Scenario: Disconnect and reconnect an enrolled radar
- **WHEN** the last valid path is removed from a radar with open channels and a valid path is later restored to that same entity in the same force and surface
- **THEN** discovery again exposes the same opaque name and channel set
- **AND** no traffic missed during detachment is replayed and no recurring polling is required during dormancy.

#### Scenario: One of several computer paths remains
- **WHEN** one computer disconnects but another valid computer-rooted path remains
- **THEN** the remaining computer retains access with the same identity and channels
- **AND** the disconnected caller cannot use its old wrapper as authority.

#### Scenario: Destroy a dormant radar without a raised removal event
- **WHEN** another mod destroys a dormant radar without raising the ordinary removal event
- **THEN** its retained identity is retired through targeted lifecycle handling without a periodic dormant scan
- **AND** a later entity at the same position cannot inherit its channels or identity.

#### Scenario: Dormant radar changes scope
- **WHEN** a dormant radar becomes reachable in a different force or surface
- **THEN** scope reconciliation invalidates old bindings and clears channels before any modem operation or message participation in that new scope
- **AND** no dormant availability polling is needed to enforce that boundary.

### Requirement: Legacy radar tracking is excluded before ticking resumes
Upgrading a supported existing save SHALL remove legacy computer-independent radar work before its first ordinary tick. Migration SHALL preserve accepted identities, channels, native entities and unrelated runtime state. It SHALL NOT require player rewiring, radar replacement or an amortized per-radar cleanup sweep during gameplay. Ordinary reloads SHALL preserve the resulting separation without mutating authoritative state in load callbacks.

#### Scenario: Upgrade an idle radar-heavy save
- **WHEN** a save made by the previous release contains eagerly enrolled unwired radars and no computers
- **THEN** the upgrade retains their identity/channel data but excludes them from all recurring work before ordinary ticking resumes
- **AND** the first measured gameplay tick already satisfies the disconnected-radar exclusion.

#### Scenario: Upgrade mixed connected and disconnected networks
- **WHEN** an old save contains working connected radars and unrelated eagerly enrolled radars
- **THEN** the unrelated records become dormant before ordinary ticking resumes
- **AND** connected radars remain usable through existing physical paths with preserved identities/channels, subject only to the existing bounded discovery/pending contract
- **AND** unrelated computer state, queued events and spent credits are not reset.

#### Scenario: Reload the migrated save
- **WHEN** the upgraded game is saved and loaded in another engine process
- **THEN** dormant radars remain outside recurring work from the first ordinary tick
- **AND** the migration is not repeated as a gameplay radar sweep and later reconnection restores the retained same-scope state.
