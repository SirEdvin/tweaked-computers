# Spec Delta

## Purpose

Let computer programs use existing Factorio programmable speakers for discoverable, bounded local notes and sound effects while preserving native factory behavior and multiplayer-safe peripheral authority.

## ADDED Requirements

### Requirement: Existing native speakers are peripherals
The existing `programmable-speaker` entity SHALL expose type `speaker` through its native red/green connectors without replacement, an adapter, helper entities or new research. It SHALL use opaque exact-entity identities and the standard discovery, metadata, wrapper and attach/detach contracts. Other speaker prototype names SHALL remain unsupported in this version.

#### Scenario: Connect a vanilla speaker
- **WHEN** a same-force speaker is connected to a computer network by a complete red path
- **THEN** discovery exposes one `speaker` on red with its current position, surface, quality, native footprint and power status
- **AND** its existing entity, inventory cost and native connectors remain unchanged.

#### Scenario: Same speaker through both colors
- **WHEN** independent valid red and green paths reach one speaker
- **THEN** both channels expose the same physical identity with separately authorized wrappers and shared playback allowances.

#### Scenario: Unsupported speaker-like entity
- **WHEN** another mod adds a differently named programmable-speaker prototype
- **THEN** that entity does not become a peripheral implicitly and remains intact as a native entity.

### Requirement: Native operation remains intact
Peripheral attachment and calls SHALL preserve native GUI access, circuit settings and playback, alerts, wires, power behavior, recipes, research, blueprints and mining results. Registration SHALL NOT make the speaker a protected implementation entity for Configurator access. Audio calls SHALL leave all native configuration unchanged after returning, including on rejected calls.

#### Scenario: Native configuration and computer playback coexist
- **WHEN** a speaker has circuit playback, alert settings and a nonlocal native playback mode configured before attachment
- **THEN** computer-requested audio is still local, the native GUI remains available, and configuration snapshots before and after each call are equal
- **AND** subsequent circuit-triggered playback follows the preserved native settings.

#### Scenario: Configurator still edits a registered speaker
- **WHEN** an authorized Configurator reaches a speaker already registered as a peripheral
- **THEN** its supported circuit settings remain readable and writable under existing validation and target-network rules
- **AND** composite implementation helpers remain protected.

#### Scenario: Registration capacity is exhausted
- **WHEN** the host cannot admit another speaker identity
- **THEN** it reports an explicit capacity/pending diagnostic without destroying, refunding, disabling or reconfiguring the player's speaker.

### Requirement: Discoverable Factorio instruments and notes
`getInstruments` and `getNotes` SHALL return defensive, complete plain-data inventories for the supported speaker's current instrument catalogue. `playNote` SHALL accept the exact instrument name, a bounded volume and a discovered zero-based note index. Invalid names, indices, volumes and argument shapes SHALL fail before playback. The companion Lua API SHALL define defaults and exact returns.

#### Scenario: Discover and play a piano note
- **WHEN** a program lists instruments, selects `piano`, lists its notes and submits one returned index
- **THEN** the selected Factorio note is requested with the specified volume without assuming Minecraft instrument names or a universal note range.

#### Scenario: Instrument-specific range
- **WHEN** a program requests a pitch outside the selected instrument's note inventory
- **THEN** it receives `E_RANGE`, no audio is submitted, and native configuration is unchanged.

#### Scenario: Snapshot isolation and size refusal
- **WHEN** a caller edits an inventory snapshot or requests an inventory that cannot fit the documented bounds
- **THEN** editing the snapshot cannot change playback metadata, and an oversized inventory fails explicitly rather than returning an unmarked prefix.

### Requirement: Validated sound playback and sound discovery
`playSound` SHALL accept valid Factorio sound paths within the published input bounds and a volume in the supported range. `getSounds` SHALL enumerate the documented catalogue through deterministic sorted pages with a literal prefix filter and explicit continuation. Returned paths SHALL be runtime-valid. File paths, URLs, raw samples and pitch-resampling parameters SHALL NOT be accepted as alternative playback mechanisms.

#### Scenario: Play a discovered effect
- **WHEN** a program discovers a valid utility or registered sound path and passes it to `playSound`
- **THEN** that sound is requested at the speaker without requiring the program to know an asset filename.

#### Scenario: Complete pagination
- **WHEN** a fixed supported installation has more matching paths than one page permits
- **THEN** successive continuation requests enumerate all matching catalogue paths once in ascending bytewise order
- **AND** only the terminal page omits continuation; no page implies that a bounded prefix is the entire catalogue.

#### Scenario: Empty prefix result and invalid path
- **WHEN** a prefix has no matches, or a program submits an invalid sound path
- **THEN** discovery returns an empty terminal page, while playback raises `E_RANGE` without sound or native-setting changes.

#### Scenario: Sound registered after catalogue capture
- **WHEN** another mod adds a valid path after the documented prototype-stage catalogue capture point
- **THEN** a direct bounded `playSound` request can still validate and play it
- **AND** documentation does not falsely promise that discovery indexes later additions.

### Requirement: Local audibility is separate from control authority
Both playback methods SHALL originate audio at the speaker's current position on its current surface. Nearby players SHALL be eligible to hear it regardless of force, subject to engine charting, attenuation and audio settings. Native global/surface playback settings SHALL NOT broaden these API calls. Hearing audio SHALL NOT confer peripheral access; no global or force-broadcast mode SHALL be exposed.

#### Scenario: Listener from another force
- **WHEN** a nearby player of another force can hear the charted location under normal client audio rules
- **THEN** local computer-requested audio is not force-filtered
- **AND** that player's computer cannot control the speaker without the existing same-force physical authority.

#### Scenario: Native speaker is configured globally
- **WHEN** a program submits a note or sound to a native speaker configured for global playback
- **THEN** the API request remains positional rather than broadcasting globally, and the configured native mode is preserved.

#### Scenario: Far or other-surface listener
- **WHEN** a listener is outside the sound's native audible range or on another surface
- **THEN** the API does not replace local playback with a global notification or player-centered sound.

### Requirement: Deterministic bounded playback admission
Playback SHALL enforce finite per-speaker, per-computer and aggregate per-tick allowances shared across programs, Console calls and wire colors. Playback methods SHALL return one boolean: true for an accepted engine submission, false for exhausted playback allowances. Validation, authority and work-budget errors SHALL remain typed errors. Allowance refusal SHALL submit no audio and enqueue no later playback.

#### Scenario: Shared speaker allowance
- **WHEN** two authorized computers or both wire colors call one speaker in the same tick until its allowance is exhausted
- **THEN** calls share one physical-speaker allowance in synchronized dispatch order and later refused calls return false without sound.

#### Scenario: Computer and aggregate limits
- **WHEN** a program alternates speakers or alternates program and Console calls to exceed a published aggregate allowance
- **THEN** changing the wrapper, color or execution principal does not renew the applicable computer/world allowance.

#### Scenario: Mixer drops an accepted request
- **WHEN** the host accepts a request but native polyphony, attenuation, charting or a client's mute setting prevents audible output
- **THEN** the result remains a deterministic submission result, not a client-dependent acknowledgement or completion event.

### Requirement: Native power and immediate revocation
Discovery and same-color relay SHALL remain power-independent. Except for `getLimits`, speaker methods SHALL require live native electrical availability. Script disablement, freezing and deconstruction SHALL refuse active service; an unfulfilled native circuit playback condition alone SHALL NOT prevent direct API playback. Every call SHALL reprove exact identity, force, surface and current wire authority before side effects.

#### Scenario: Unpowered relay
- **WHEN** a speaker loses electrical power while its physical wires remain valid
- **THEN** it and devices beyond it remain discoverable, `getLimits` remains callable, and other speaker methods fail `E_UNPOWERED` without new audio.

#### Scenario: No circuit signal is present
- **WHEN** a powered otherwise operational speaker has an unfulfilled circuit playback condition
- **THEN** an authorized direct API note does not require a synthetic signal or a change to that condition.

#### Scenario: Cable or force changes
- **WHEN** a retained wrapper is used after its authorized path is removed or the speaker changes force/surface
- **THEN** the call fails closed before audio rather than trusting a stale inventory or retargeting by position.

### Requirement: Existing-save adoption and exact lifecycle
Physically reachable speakers placed before installation or without a raised build event SHALL become discoverable through bounded synchronized reconciliation. Incomplete adoption SHALL report pending/capacity rather than successful omission. Mining, destruction, cloning, revival, relocation and force/surface changes SHALL preserve native behavior while maintaining exact peripheral identity and invalidating obsolete authority.

#### Scenario: Existing connected factory
- **WHEN** the mod is upgraded in a world containing already-wired vanilla speakers
- **THEN** supported reachable speakers are adopted without re-placement, global every-tick world scans or startup audio
- **AND** their native settings and wires are preserved.

#### Scenario: Replacement or cloned speaker
- **WHEN** a speaker is mined and replaced or cloned
- **THEN** the new entity obtains a distinct identity, old bindings cannot control it, and no queued audio or spent identity is copied through an item or blueprint.

#### Scenario: Unregistered removal
- **WHEN** a registered speaker is invalidated without a raised removal event
- **THEN** subsequent calls reject it immediately and bounded maintenance removes its stale registration without deleting a replacement at the old coordinates.

### Requirement: Reload does not replay audio or refresh credits
Ordinary save/load SHALL preserve exact speaker identities and spent admission state without rerunning startup handlers, replaying previously submitted audio or renewing same-tick allowances. No playback queue, live native playback handle or client completion state SHALL be persisted. Reconnection or late joining SHALL NOT trigger replay; continuation of already audible samples across reload is not promised.

#### Scenario: Same-tick cold reload
- **WHEN** a save is resumed with already-spent speaker/computer/world allowances for the restored tick
- **THEN** further calls in that tick retain those deductions and a genuinely later tick renews allowances normally.

#### Scenario: Stop or detach after submission
- **WHEN** a program stops, loses power or disconnects after submitting a sound
- **THEN** it cannot submit further unauthorized audio, but the API does not promise cancellation of sound already handed to clients.

### Requirement: Explicit compatibility and exact API inventory
The speaker SHALL expose exactly `playNote`, `playSound`, `getInstruments`, `getNotes`, `getSounds` and `getLimits` under the companion Lua API. It SHALL NOT advertise `playAudio`, `stop`, raw audio streaming, sound-speed control, sample-accurate sequencing or completion events. Both saved-handler programs and the existing Console SHALL use the same synchronous service and limits.

#### Scenario: Inspect available methods
- **WHEN** a program inspects a speaker's public method list
- **THEN** it receives only the documented methods and cannot discover a stub claiming unsupported CC:Tweaked audio compatibility.

### Requirement: Packaged audio acceptance
Acceptance SHALL exercise the exact packaged archive with base and Space Age 2.0.77, real native wiring/lifecycle, cold reload and actual connected clients. Evidence SHALL distinguish API/native-state assertions from audible output. Headless success, screenshots, silent video and engine acceptance booleans SHALL NOT be represented as proof of sound or connected-multiplayer delivery.

#### Scenario: Native listener acceptance
- **WHEN** the release candidate is accepted
- **THEN** native-client audio evidence verifies notes, volume, simultaneous requests, effect playback and near/far/other-force/other-surface listeners
- **AND** connected peers verify consistent admission and no duplicate playback after reload or late joining.
