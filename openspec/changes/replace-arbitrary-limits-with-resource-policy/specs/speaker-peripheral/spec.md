## MODIFIED Requirements

### Requirement: Discoverable Factorio instruments and notes
`getInstruments` and `getNotes` SHALL return defensive, complete plain-data inventories for the supported speaker's current instrument catalogue. `playNote` SHALL accept the exact instrument name, a bounded volume and a discovered zero-based note index. Invalid names, indices, volumes and argument shapes SHALL fail before playback. The companion Lua API SHALL define defaults and exact returns.

#### Scenario: Discover and play a piano note
- **WHEN** a program lists instruments, selects `piano`, lists its notes and submits one returned index
- **THEN** the selected Factorio note is requested with the specified volume without assuming Minecraft instrument names or a universal note range.

#### Scenario: Instrument-specific range
- **WHEN** a program requests a pitch outside the selected instrument's note inventory
- **THEN** it receives `E_RANGE`, no audio is submitted, and native configuration is unchanged.

#### Scenario: Snapshot isolation and size refusal
- **WHEN** a caller edits an inventory snapshot or requests an inventory that cannot fit configured aggregate resources
- **THEN** editing the snapshot cannot change playback metadata; insufficient aggregate resources cause recoverable refusal rather than an unmarked prefix, and no instrument/note-count ceiling applies.

### Requirement: Validated sound playback and sound discovery
`playSound` SHALL accept valid Factorio sound paths within actual native validity rules and a volume in the supported range. `getSounds` SHALL enumerate the documented catalogue through deterministic sorted pages with a literal prefix filter and explicit continuation, without a fixed catalogue-size ceiling. Returned paths SHALL be runtime-valid. File paths, URLs, raw samples and pitch-resampling parameters SHALL NOT be accepted as alternative playback mechanisms.

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

### Requirement: Deterministic bounded playback admission
Playback SHALL use shared work and retained-resource policy without independent note/sound/submission-count ceilings. Work exhaustion SHALL suspend before submission and resume with authority revalidation. Playback SHALL return true only after one engine submission; hard-resource/native refusals SHALL be recoverable typed errors. No partial or duplicate audio SHALL be submitted.

#### Scenario: Shared speaker allowance
- **WHEN** two authorized computers or both wire colors call one speaker in the same tick until the current work slice is exhausted
- **THEN** calls share configured resource budgets in synchronized order and later calls wait for admission rather than return false due to a note-count ceiling.

#### Scenario: Computer and aggregate limits
- **WHEN** a program alternates speakers or alternates program and Console calls to exceed configured aggregate work allowance
- **THEN** changing the wrapper, color or execution principal does not renew the applicable computer/world allowance.

#### Scenario: Mixer drops an accepted request
- **WHEN** the host accepts a request but native polyphony, attenuation, charting or a client's mute setting prevents audible output
- **THEN** the result remains a deterministic submission result, not a client-dependent acknowledgement or completion event.

### Requirement: Reload does not replay audio or refresh credits
Ordinary save/load SHALL preserve exact speaker identities and spent admission state without rerunning startup handlers, replaying previously submitted audio or renewing same-tick allowances. Only an unsubmitted call continuation SHALL persist; no submitted playback handle or client completion state SHALL be persisted. Reconnection or late joining SHALL NOT trigger replay; continuation of already audible samples across reload is not promised.

#### Scenario: Same-tick cold reload
- **WHEN** a save is resumed with already-spent computer/shared resource allowances for the restored tick
- **THEN** further calls in that tick retain those deductions and a genuinely later tick renews allowances normally.

#### Scenario: Stop or detach after submission
- **WHEN** a program stops, loses power or disconnects after submitting a sound
- **THEN** it cannot submit further unauthorized audio, but the API does not promise cancellation of sound already handed to clients.

### Requirement: Explicit compatibility and exact API inventory
The speaker SHALL expose exactly `playNote`, `playSound`, `getInstruments`, `getNotes`, `getSounds` and `getLimits` under the companion Lua API. It SHALL NOT advertise `playAudio`, `stop`, raw audio streaming, sound-speed control, sample-accurate sequencing or completion events. Both saved-handler programs and the existing Console SHALL use the same sequential service results and resumable resource policy.

#### Scenario: Inspect available methods
- **WHEN** a program inspects a speaker's public method list
- **THEN** it receives only the documented methods and cannot discover a stub claiming unsupported CC:Tweaked audio compatibility.

## ADDED Requirements

### Requirement: Catalogue pages are not capacity ceilings
Sound discovery SHALL retain compatible cursor/page results while making every matching captured catalogue path reachable. Page size SHALL be a configurable resource/retention parameter, not a total-inventory cap. Instrument and note arrays SHALL remain complete under aggregate resource admission.

#### Scenario: Large installed sound inventory
- **WHEN** installed catalogues exceed former instrument, note or sound-count maxima
- **THEN** callers can obtain complete inventories or traverse all sound pages without a fixed-count refusal.
