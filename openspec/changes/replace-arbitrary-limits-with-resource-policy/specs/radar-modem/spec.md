## MODIFIED Requirements

### Requirement: Familiar wireless modem methods
A modem SHALL provide strict dot-call `open(channel)`, `isOpen(channel)`, `close(channel)`, `closeAll()`, `transmit(channel, replyChannel, payload)`, `isWireless()` and `getLimits()` as specified in `lua-api.md`. Channels SHALL be nonnegative exactly representable safe integers, without the mod-invented 65535 ceiling. `isWireless()` SHALL return true for both tiers. Wired-modem remote methods, rednet and blocking event waits SHALL NOT be provided.

#### Scenario: Validate channel arguments
- **WHEN** a call supplies a fractional, out-of-range or incorrectly typed channel, a colon-call receiver or an extra argument
- **THEN** it fails with the documented typed error without modifying channels or publishing messages.

#### Scenario: Transmit on a closed channel
- **WHEN** a valid `transmit` call uses channels not opened by the sending radar
- **THEN** transmission is permitted and the reply channel is copied as sender-selected metadata, not opened automatically.

### Requirement: Shared bounded open channels
Each physical radar SHALL retain one shared resource-accounted set of open channels without a fixed count ceiling. Opening an open channel and closing a closed channel SHALL be idempotent. `closeAll` SHALL clear that radar's shared set only. Authorized computers and both wire colors SHALL observe the same committed set in synchronized call order; one computer stopping SHALL NOT close channels for other users.

#### Scenario: Shared access and capacity
- **WHEN** two computers access the same radar and the first has opened 128 distinct channels
- **THEN** the second observes those channels, can reopen an existing channel, and can open another when aggregate retained resources admit it
- **AND** a capacity refusal preserves the complete previous set.

#### Scenario: Closing is not recalling a message
- **WHEN** a channel is closed after a message was admitted to a computer's queue
- **THEN** subsequent transmissions do not select that channel and the already admitted event remains a valid snapshot.

### Requirement: Deterministic bounded admission
Routing, payload copying and fan-out SHALL be bounded and charged before publication. Incomplete route preparation SHALL retain progress without publishing a prefix. Once accepted, delivery SHALL advance in deterministic order across ticks without replaying already processed recipients. Queue overflow SHALL drop that newest recipient event with a persistent diagnostic, not fault its run. No guest retry protocol or callbacks inside transmit SHALL be introduced.

#### Scenario: Invalid or oversized broadcast
- **WHEN** a transmission cannot fit configured retained resources or encounters a definitively invalid route
- **THEN** it fails before publishing any message and reports a documented diagnostic rather than successful partial routing.

#### Scenario: One full recipient queue
- **WHEN** an otherwise admitted transmission encounters a recipient queue with insufficient capacity
- **THEN** that delivery is dropped newest and counted without stopping the run, other eligible recipients continue in deterministic order, and the sender is not told to retry a partially published transmission.

#### Scenario: Callback sends another message
- **WHEN** a modem handler transmits a response
- **THEN** receiver callbacks are queued and never execute recursively inside that transmission call.

### Requirement: Durable transport state without replay
Ordinary cold save/load SHALL preserve radar identities, open channels, registered handlers, admitted event order, unfinished delivery progress and spent same-tick resource credits without re-transmitting packets or replaying startup. Mining, replacement, cloning and blueprint placement SHALL NOT transfer open channels or message queues. Radar force/surface reassignment SHALL revoke old authority and reset channels before participation in the new scope.

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
`getLimits` SHALL expose native-safe channel domains and effective configured resource allowances, with no independent open-channel, candidate, delivery or transmission-count ceilings. Tier metadata SHALL distinguish surface-only from interplanetary transport. Documentation SHALL publish measured supported workloads and overload behavior without representing radio range as a computational resource exemption.

#### Scenario: Diagnose an unsupported broadcast
- **WHEN** a program reads a reachable modem's limits after a capacity refusal
- **THEN** it can identify the applicable resource setting and recovery action without needing native objects or world enumeration.

## ADDED Requirements

### Requirement: Broadcast continuation and loss attribution
An accepted broadcast SHALL retain its immutable payload, deterministic eligible route plan and next delivery position through suspension and cold reload. Each destination SHALL be revalidated before publication. An overflowed or now-unavailable destination SHALL be recorded once as a dropped delivery rather than retried or silently omitted.

#### Scenario: More than eight deliveries
- **WHEN** a broadcast addresses more than eight valid handler deliveries or 64 routing candidates with adequate retained resources
- **THEN** all eligible destinations are processed across fair work slices; every delivery is either enqueued once or explicitly accounted as lost.

#### Scenario: Reload after a delivered prefix
- **WHEN** a save occurs after some destinations were processed
- **THEN** the remaining plan resumes without retransmitting to the processed prefix or invoking sender startup.
