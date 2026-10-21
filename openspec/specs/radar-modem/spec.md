# radar-modem Specification

## Purpose

Let computers exchange bounded channel-addressed messages through physically attached radars, with same-surface coverage and an optional Space Age interplanetary tier, without granting remote peripheral authority.

## Requirements

### Requirement: Native radar modem identity
The vanilla `radar` and optional advanced radar SHALL expose peripheral type `modem` through explicit local red/green discovery. Each placed radar SHALL have one stable opaque identity across ordinary saves and both wire colors. Native radar functions SHALL remain intact, and metadata SHALL identify the tier without exposing native objects.

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

### Requirement: Familiar wireless modem methods
A modem SHALL provide strict dot-call `open(channel)`, `isOpen(channel)`, `close(channel)`, `closeAll()`, `transmit(channel, replyChannel, payload)`, `isWireless()` and `getLimits()` as specified in `lua-api.md`. Channels SHALL be integers from 0 through 65535. `isWireless()` SHALL return true for both tiers. Wired-modem remote methods, rednet and blocking event waits SHALL NOT be provided.

#### Scenario: Validate channel arguments
- **WHEN** a call supplies a fractional, out-of-range or incorrectly typed channel, a colon-call receiver or an extra argument
- **THEN** it fails with the documented typed error without modifying channels or publishing messages.

#### Scenario: Transmit on a closed channel
- **WHEN** a valid `transmit` call uses channels not opened by the sending radar
- **THEN** transmission is permitted and the reply channel is copied as sender-selected metadata, not opened automatically.

### Requirement: Shared bounded open channels
Each physical radar SHALL retain one shared set of at most 128 open channels. Opening an open channel and closing a closed channel SHALL be idempotent. `closeAll` SHALL clear that radar's shared set only. Authorized computers and both wire colors SHALL observe the same committed set in synchronized call order; one computer stopping SHALL NOT close channels for other users.

#### Scenario: Shared access and capacity
- **WHEN** two computers access the same radar and the first has opened 128 distinct channels
- **THEN** the second observes those channels, can reopen an existing channel, and cannot open a new one until a slot is freed
- **AND** a capacity refusal preserves the complete previous set.

#### Scenario: Closing is not recalling a message
- **WHEN** a channel is closed after a message was admitted to a computer's queue
- **THEN** subsequent transmissions do not select that channel and the already admitted event remains a valid snapshot.

### Requirement: Same-surface broadcast and force isolation
A transmission SHALL reach eligible listening radars anywhere on the sender's surface, regardless of distance or tier, but only within the sender's exact force. Allies SHALL NOT receive by alliance alone. The sending physical radar SHALL NOT receive its own transmission. Other receiving radars attached to the sending computer SHALL remain eligible.

#### Scenario: Distant independent networks
- **WHEN** two powered ordinary radars on the same surface and force are attached to separate computers, and the receiver has opened the transmitted channel
- **THEN** the registered receiver obtains the message even outside the sender's scanning coverage and without a physical path between the radars.

#### Scenario: Different force or closed channel
- **WHEN** a nearby radar belongs to another force or has not opened the channel
- **THEN** it receives no message, including when its force is allied.

#### Scenario: No same-radar echo
- **WHEN** a sending radar has opened the transmitted channel and multiple computers are attached to it
- **THEN** none receives a local echo through that radar, while distinct eligible receiving radars remain eligible.

### Requirement: Expansion-gated cross-surface transport
Without Space Age, the advanced radar SHALL be absent and ordinary radar messages SHALL remain on one surface. With Space Age, messages SHALL cross surfaces only when both sending and receiving radars are advanced. Planet and space-platform surfaces SHALL participate without an orbit, stationarity or same-space-location restriction. This transport SHALL NOT create cross-surface physical discovery.

#### Scenario: Advanced pair on different planets
- **WHEN** powered advanced radars on different planets belong to the same force and the receiving channel is open
- **THEN** the receiving computer obtains the message with no distance value.

#### Scenario: Platform in flight
- **WHEN** an advanced radar on a travelling space platform communicates with an advanced radar on another eligible surface
- **THEN** the platform's travel state does not disable the message route.

#### Scenario: Mixed-tier boundary
- **WHEN** an ordinary radar and an advanced radar use the same channel
- **THEN** they can communicate on the same surface but neither direction crosses surfaces.

### Requirement: Named modem message events
Saved programs SHALL register `modem_message` using the existing named-handler API. Receipt SHALL enqueue a defensive event containing the receiving peripheral, qualifying local wires, channel, `replyChannel`, message and same-surface distance. Cross-surface distance SHALL be absent. Both-color reachability SHALL produce one event per receiving radar and handler registration, not one per wire.

#### Scenario: Both-color receive deduplication
- **WHEN** a computer with one registered handler reaches the same receiving radar on red and green
- **THEN** it receives one event with `wires = {"red", "green"}` and canonical `wire = "red"`.

#### Scenario: Multiple receiving radars
- **WHEN** two different attached radars receive one transmission and a computer has one registered handler
- **THEN** that computer receives one event for each receiving radar, with distinct peripheral names.

#### Scenario: Receipt precedes detachment
- **WHEN** a valid receive event is enqueued and the local wire is then removed before callback dispatch
- **THEN** the callback can read the accepted message snapshot but cannot use it as authority for any subsequent peripheral operation.

### Requirement: Defensive message payloads
Messages SHALL accept bounded shared-contract Data or explicit top-level nil. Validation SHALL reject functions, native objects, facades, metatables, cycles, non-finite numbers and unsupported table shapes instead of silently stripping them. Each delivery SHALL own a defensive copy. Payload admission SHALL include event-envelope overhead and total fan-out work, not just source payload size.

#### Scenario: Sender and receiver mutations
- **WHEN** the sender changes its original table after transmitting and one receiver changes its event message
- **THEN** neither change affects other recipients or the already accepted payload snapshot.

#### Scenario: Nil and false are distinct
- **WHEN** valid transmissions contain explicit nil and false payloads
- **THEN** both are delivered and the receiving handler observes nil and false respectively.

### Requirement: Deterministic bounded admission
Routing, payload copying and fan-out SHALL be bounded and charged before publication. An incomplete relevant topology proof or request-level limit refusal SHALL publish no recipient prefix. Accepted messages SHALL enter existing deterministic non-reentrant queues without acknowledgements, retries or background callbacks. Recipient queue overflow SHALL visibly fault that recipient under existing runtime rules, not silently discard admitted work.

#### Scenario: Invalid or oversized broadcast
- **WHEN** a transmission exceeds a published payload, recipient or throughput bound, or cannot establish complete relevant local reachability
- **THEN** it fails before publishing any message and reports a documented diagnostic rather than successful partial routing.

#### Scenario: One full recipient queue
- **WHEN** an otherwise admitted transmission encounters a recipient queue with insufficient capacity
- **THEN** that run visibly faults under the existing overflow policy, other eligible recipients are processed in deterministic order, and the sender is not told to retry a partially published transmission.

#### Scenario: Callback sends another message
- **WHEN** a modem handler transmits a response
- **THEN** receiver callbacks are queued and never execute recursively inside that transmission call.

### Requirement: Availability and outage semantics
Transmission and reception SHALL require a live, active, electrically supplied radar and current local authority. Discovery, metadata and `getLimits` SHALL remain available for an unpowered reachable radar; other modem methods SHALL refuse with `E_UNPOWERED`. Outages SHALL preserve open channels but SHALL NOT accumulate or replay radio traffic missed while a radar or receiving computer was unavailable.

#### Scenario: Radar power cycle
- **WHEN** a listening radar loses and regains power without being replaced
- **THEN** its channels remain open, traffic during the outage is absent, and later traffic resumes normally.

#### Scenario: Receiving computer outage
- **WHEN** a receiving computer loses power after a modem event was queued
- **THEN** the event follows the runtime's transient-event discard policy and is not replayed after restoration.

### Requirement: Durable transport state without replay
Ordinary cold save/load SHALL preserve radar identities, open channels, registered handlers, admitted event order and spent same-tick transport credits without re-transmitting packets or replaying startup. Mining, replacement, cloning and blueprint placement SHALL NOT transfer open channels or message queues. Radar force/surface reassignment SHALL revoke old authority and reset channels before participation in the new scope.

#### Scenario: Reload with queued communication
- **WHEN** a save with open channels and undelivered modem events is loaded in a separate engine process
- **THEN** each retained event is dispatched once in its existing order, and no startup or transmit effect is repeated.

#### Scenario: Replace or clone a configured radar
- **WHEN** a radar with open channels is mined/replaced, cloned or rebuilt from a blueprint
- **THEN** the new entity has a new identity and an empty channel set, and old wrappers cannot retarget to it.

#### Scenario: Scope change
- **WHEN** a radar changes force or moves to a different surface
- **THEN** its old local bindings are invalidated before further calls and its previously opened channels are cleared.

### Requirement: Queryable transport envelope
`getLimits` SHALL expose channel bounds, open-channel capacity and effective finite payload, candidate, delivery and per-tick throughput limits. Tier metadata SHALL distinguish surface-only from interplanetary transport. Documentation SHALL publish measured supported workloads and overload behavior without representing radio range as a computational resource exemption.

#### Scenario: Diagnose an unsupported broadcast
- **WHEN** a program reads a reachable modem's limits after a capacity refusal
- **THEN** it can identify the applicable finite bound without needing native objects or world enumeration.
