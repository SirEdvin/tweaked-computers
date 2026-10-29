# radar-modem delta

## MODIFIED Requirements

### Requirement: Native radar modem identity
The vanilla `radar` and optional advanced radar SHALL expose peripheral type `modem` through explicit local red/green discovery. A radar SHALL be enrolled only through a valid computer-rooted physical path. Once enrolled, its opaque identity SHALL remain stable across ordinary saves, both wire colors and same-entity, same-scope disconnection/reconnection. Native radar functions SHALL remain intact, and metadata SHALL identify the tier without exposing native objects.

#### Scenario: Attach a vanilla radar
- **WHEN** a valid computer is connected directly to an existing vanilla radar with a red circuit wire
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

### Requirement: Availability and outage semantics
Transmission and reception SHALL require a live, active, electrically supplied radar and current local authority. Discovery, metadata and `getLimits` SHALL remain available for an unpowered reachable radar; other modem methods SHALL refuse with `E_UNPOWERED`. Outages SHALL preserve open channels but SHALL NOT accumulate or replay radio traffic missed while a radar or receiving computer was unavailable.

#### Scenario: Radar power cycle
- **WHEN** a listening radar loses and regains power without being replaced
- **THEN** its channels remain open, traffic during the outage is absent, and later traffic resumes normally.

#### Scenario: Receiving computer outage
- **WHEN** electrical supply around a receiving custom computer disappears after a modem event was queued
- **THEN** that electrical change does not cancel its accepted event; ordinary stop, fault, removal and scope-retirement cancellation remain in force.

## ADDED Requirements

### Requirement: Interaction-time native radar availability
Both radar tiers SHALL retain their native energy sources, consumption and behavior. The mod SHALL evaluate power only for an actual method/metadata request or transmission sender/receiver eligibility. Open channels, remembered identity and connected topology MUST NOT create recurring power monitoring. Existing unpowered method errors and missed-traffic behavior remain unchanged.

#### Scenario: Connected idle listening radar
- **WHEN** a connected radar has open channels but no calls or transmission is being considered
- **THEN** the mod performs no proactive radar power check, regardless of whether electricity changes.

#### Scenario: Power changes between metadata and transmit
- **WHEN** a radar was described as powered but loses power before transmit
- **THEN** the fresh call fails E_UNPOWERED before publication; no saved positive power observation authorizes transmission.

#### Scenario: Unpowered receiver during transmission
- **WHEN** a candidate listening receiver is electrically unavailable when a transmission is evaluated
- **THEN** it receives no event, retains its channels and does not replay missed traffic on restoration; other eligible recipients retain existing deterministic delivery.

#### Scenario: Queued packet and later radar outage
- **WHEN** an eligible packet was accepted before the receiving radar loses power
- **THEN** the already queued data snapshot retains the existing accepted-event contract; further operations recheck current native power.
