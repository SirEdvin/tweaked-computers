# speaker-peripheral delta

## MODIFIED Requirements

### Requirement: Native power and immediate revocation
Discovery and same-color relay SHALL remain power-independent. Except for `getLimits`, speaker methods SHALL require live native electrical availability. Script disablement, freezing and deconstruction SHALL refuse active service; an unfulfilled native circuit playback condition alone SHALL NOT prevent direct API playback. The mod SHALL NOT proactively monitor speaker power; actual calls and requested metadata observations SHALL check current native availability. Every call SHALL reprove exact identity, force, surface and current wire authority before side effects.

#### Scenario: Unpowered relay
- **WHEN** a speaker loses electrical power while its physical wires remain valid
- **THEN** it and devices beyond it remain discoverable, `getLimits` remains callable, and other speaker methods fail `E_UNPOWERED` without new audio.

#### Scenario: No circuit signal is present
- **WHEN** a powered otherwise operational speaker has an unfulfilled circuit playback condition
- **THEN** an authorized direct API note does not require a synthetic signal or a change to that condition.

#### Scenario: Cable or force changes
- **WHEN** a retained wrapper is used after its authorized path is removed or the speaker changes force/surface
- **THEN** the call fails closed before audio rather than trusting a stale inventory or retargeting by position.

### Requirement: Reload does not replay audio or refresh credits
Ordinary save/load SHALL preserve exact speaker identities and spent admission state without rerunning startup handlers, replaying previously submitted audio or renewing same-tick allowances. No playback queue, live native playback handle or client completion state SHALL be persisted. Reconnection or late joining SHALL NOT trigger replay; continuation of already audible samples across reload is not promised.

#### Scenario: Same-tick cold reload
- **WHEN** a save is resumed with already-spent speaker/computer/world allowances for the restored tick
- **THEN** further calls in that tick retain those deductions and a genuinely later tick renews allowances normally.

#### Scenario: Stop or detach after submission
- **WHEN** a program stops or disconnects, or its native speaker loses power after submitting a sound
- **THEN** it cannot submit further unauthorized audio, but the API does not promise cancellation of sound already handed to clients.

## ADDED Requirements

### Requirement: Idle speakers create no availability work
A connected or remembered programmable speaker SHALL receive no recurring electrical-availability observation merely because it is a peripheral. Native playback, alerts, circuit settings and energy behavior SHALL remain untouched. Requested operations retain fresh availability checks and existing admission/return semantics.

#### Scenario: Idle powered and unpowered speaker
- **WHEN** a speaker is registered but no operation or metadata query targets it
- **THEN** the mod makes no proactive power check; native audio/circuit simulation remains Factorio's responsibility.

#### Scenario: Outage between calls
- **WHEN** a powered speaker is used successfully and then loses supply before another method call
- **THEN** the later active call raises E_UNPOWERED without audio or native-setting mutation; getLimits and permitted metadata remain available.

#### Scenario: Computer electrical supply changes
- **WHEN** electricity around the custom computer disappears but the native speaker remains operational
- **THEN** valid scheduled commands continue to use the speaker without a computer power pause or changed playback allowance.
