# Speaker Lua API v1

This is the normative API companion to [the speaker capability](spec.md) for the active development candidate, not a published release. Existing common Data, budget, authority and saved-program/Console rules continue to apply.

## Discovery and method inventory

Peripheral type: `speaker`. The supported carrier is the vanilla entity named `programmable-speaker`, not every prototype of that entity type. Use `peripheral.find("speaker", "red")`, `wrap(name, wire)` or `call(name, wire, method, ...)`; the wire is always explicitly `"red"` or `"green"`.

The exact public method set is `getInstruments`, `getLimits`, `getNotes`, `getSounds`, `playNote`, `playSound`. All calls are synchronous, non-yielding dot calls. There is no speaker subscription, audio queue, completion event or special global speaker library. Existing attach/detach events use `peripheral_type="speaker"`.

| Signature | Exact returns |
| --- | --- |
| `speaker.playNote(instrument [, volume [, pitch]])` | Exactly one boolean admission result |
| `speaker.playSound(path [, volume])` | Exactly one boolean admission result |
| `speaker.getInstruments()` | Exactly one complete dense string array |
| `speaker.getNotes(instrument)` | Exactly one complete dense `NoteInfo[]` |
| `speaker.getSounds([prefix [, after]])` | Exactly one `SoundPage` |
| `speaker.getLimits()` | Exactly one defensive map of common and speaker-specific limits |

`playNote` accepts one, two or three arguments; `playSound` one or two; `getNotes` exactly one; `getSounds` zero, one or two; the other methods zero. Explicit nil in an optional position is the same as omission. Extra arguments, colon-call receivers and option tables are rejected, not ignored.

## Notes

- `instrument` is an exact case-sensitive instrument name from `getInstruments`, for example `piano`, `drum-kit` or `alarms`. Localized display text and Minecraft instrument aliases are not accepted.
- `volume` is a finite number in `[0,1]`, default `1`. It multiplies the sample's defined volume; the client mixer and native attenuation still apply. Zero is a valid silent submission and consumes the normal playback allowance.
- `pitch` is a finite integer from `0` through the selected instrument's note count minus one, default `0`. It is the zero-based Factorio note index. It is not a frequency, MIDI number or universally meaningful semitone offset, and there is no fixed CC:Tweaked `0..24` range.
- `getInstruments()` returns unique names in ascending bytewise order.
- `getNotes(instrument)` returns records in native note order. Each record has exactly `pitch:integer` and `name:string`. Its `pitch` can be passed directly to `playNote`; the surrounding Lua result array remains one-based.
- Note labels are descriptive and case-sensitive. For example, the first piano sample in the pinned base catalogue is labelled `F3` and has pitch `0`; programs should discover rather than hardcode a label-to-index map.
- Inventories are copied plain data. No sound filename, native prototype object or mutable host catalogue is exposed. Duplicate instrument names, malformed definitions or unrepresentable metadata fail explicitly rather than selecting an arbitrary duplicate or truncating the inventory.

The notes service uses Factorio's existing instrument sample definitions independently of the speaker's native circuit-triggered playback settings. The native circuit condition, selected instrument/note, volume-by-signal, global/surface mode and allow-polyphony setting are not controls for the API request. Those settings are neither permanently rewritten nor used to broadcast API audio. Native circuit playback can still run alongside API audio.

## Sound paths

`playSound(path [, volume])` requests an engine-valid `SoundPath` at the speaker's location. Volume has the same range and default as `playNote`. `path` must be an exact nonempty string within `speaker_path_bytes`; whitespace, case and punctuation are never normalized.

Accepted path families are those supported by Factorio 2.0.77, including named sound prototypes and valid `utility/`, `ambient/`, `entity-*`, `tile-*` and `item-*` sound paths. Native validation is the final authority: a plausible prefix or a name in an old catalogue is not enough. A valid path added by another mod can be played directly even when absent from discovery. Paths are sound identifiers, not permission to read arbitrary files or fetch URLs. Passing a raw game/mod filename is not an alternate audio loader.

There is no speed/pitch argument, duration argument, looping flag, caller-chosen position/surface, target-player list or global-mode flag. An already submitted long sample is not cancellable through this API.

## Sound discovery

`getSounds([prefix [, after]])` returns:

- `sounds`: a dense array of unique runtime-valid sound-path strings, in ascending bytewise order, with at most `speaker_sound_page_size` entries.
- `next`: optional string. Present only when another matching valid catalogue path exists. Pass it as `after` to fetch the next page. It is the last emitted path, not a numeric offset, live iterator or stored query session.

There is no `total` or approximate count. An empty result is `{sounds={}}`, with `next` absent. A full page with no remaining match also omits `next`. In a fixed catalogue, continuation never duplicates a returned path or skips an eligible path.

`prefix` defaults to the empty string and is a literal case-sensitive prefix, not a Lua pattern or glob. `after` defaults to the empty string and is an exclusive bytewise lower bound. Both can be empty and obey `speaker_path_bytes`; a supplied lower-bound key need not exist or share the prefix. The next page is the earliest matching valid paths lexically greater than `after`. Changing filters begins a different traversal; there is no hidden cursor authority or expiration.

Discovery indexes the following candidates visible at this mod's `data-final-fixes` capture point:

- Named `sound` prototypes, excluding this feature's private generated note aliases.
- Utility and ambient paths identified by the pinned path rules.
- Applicable entity, tile and item path families identified by those rules.

Candidate entries are deduplicated and sorted. Runtime-invalid candidates are not returned. With the supported base-only and Space Age mod sets, paging the catalogue covers all valid candidates from these families. Third-party additions after this mod's capture point are not promised discoverable; direct `playSound` still validates them. Removing a prototype can invalidate an old returned path. Treat a changed mod configuration as a new catalogue and restart traversal if a complete new inventory is required.

A missing, oversized, incompatible or malformed catalogue returns a typed error, not an undocumented curated subset. Budget exhaustion during a page returns no partial page or fabricated terminal marker. Catalogue failure does not by itself disable direct validation/playback of sound paths or unrelated peripherals.

## Admission, timing and audibility

Both playback methods return `true` only when the host has admitted the request and submitted it to the engine. `false` means a speaker, computer or world playback allowance was already exhausted; no audio was submitted or queued by that refused call. Other failures are errors, not false. The return value never depends on a particular player's position, mute setting, rendered audio or whether a client exists.

Each tick has separate physical-speaker note and sound allowances plus combined per-computer and world submission allowances. Two wrappers/colors/computers share a speaker's allowance. One computer's saved program and all Console calls share its combined allowance. A world allowance covers all computers, forces and surfaces. All successful submissions, including zero-volume ones, count once against their applicable allowances, regardless of listener count.

Validation and all possible work admission occur before audio dispatch. Invalid calls consume no playback quota, although already spent validation/work credits remain spent. Allowance refusal consumes no additional playback quota. Once dispatch is attempted, its allowance remains consumed even if native dispatch raises an error; do not automatically retry an uncertain external audio effect. No callback restart, exception handler, wrapper recreation, disconnect/reconnect, program Apply or same-tick reload renews existing identity allowances. New entities get new identity-local state, but surviving computer/world allowances are not reset by replacement.

Use named timers for later notes. The API does not buffer a song, guarantee sample-accurate timing or report when a note finishes. Simulation scheduling and client audio rendering are different clocks. Native mixer/aggregation limits can drop or combine accepted sounds; `true` is not proof of audible delivery or an exact simultaneous-voice count.

Audio is positional on the speaker's current surface, not force-filtered. The engine's charting, listener position/view, sound-specific attenuation and audio settings determine what is actually heard. Note playback uses local game-effect samples; it does not promise the native speaker entity's exact audible radius or native circuit polyphony settings. Other sound paths retain their sound-specific spatial behavior under a positional game-effect request. No global fallback is permitted if a sound cannot satisfy local playback; engine acceptance must cover the documented supported path families.

## Availability, identity and native coexistence

Native electrical/operational availability is checked at interaction and playback submission, not by proactive generic-lifecycle power polling. Custom computers need no electricity; this does not change the speaker's native energy settings or replay missed notes.

- `getLimits` works whenever the exact peripheral remains reachable, including when unpowered. Every other method requires live availability, matching existing peripheral conventions.
- The speaker must retain positive native electrical energy and must not be script-disabled, frozen or marked for deconstruction. A false circuit playback condition alone is not an API outage. Unavailable service reports `E_UNPOWERED`; discovery and same-color relay remain intact.
- Every call reproves exact identity, force, surface and selected wire. Stale wrappers cannot control replacements; coordinates and labels remain descriptive only.
- Native circuit playback is independent and does not consume the API admission counters. Native GUI and Configurator edits remain available. No API call changes alerts, circuit settings, native volume, playback mode, wires, power buffers or energy consumption.
- Stop, disconnect, outage and destruction prevent subsequent unauthorized submissions but do not promise cancellation of samples already dispatched. Reload and late joining do not replay old submissions. The feature persists admission/identity data only, not audio queues or client playback state.
- Standard program facades are callback-local and cannot be stored as Data. Store the peripheral name and wire, then wrap again. Existing Console symbolic bindings remain supported with the same live checks; they add no background playback loop.

## Limits

`getLimits()` returns the current common limits plus the fields below. These are explicit initial bounded defaults, not measured throughput claims. Release acceptance must validate them under unchanged common budgets; changing these contract defaults requires a documented revision, not silently raising production budgets to make a test pass.

| Field | Initial value | Meaning |
| --- | --- | --- |
| `speaker_path_bytes` | 256 | Maximum UTF-8 bytes in sound paths and discovery prefix/lower-bound strings |
| `speaker_instruments` | 64 | Maximum complete instrument inventory |
| `speaker_notes_per_instrument` | 128 | Maximum complete note inventory for one instrument |
| `speaker_sound_page_size` | 50 | Maximum valid sound paths in one page |
| `speaker_sound_catalog_entries` | 32768 | Maximum unique captured candidate paths before runtime validation; overflow is explicit, never truncation |
| `speaker_notes_per_tick` | 8 | Note submissions per physical speaker per simulation tick |
| `speaker_sounds_per_tick` | 1 | Sound-effect submissions per physical speaker per simulation tick |
| `speaker_computer_submissions_per_tick` | 16 | Combined note/effect submissions per computer identity per tick |
| `speaker_world_submissions_per_tick` | 64 | Combined note/effect submissions across the world per tick |

Instrument and note names also fit `speaker_path_bytes`. Common tuple/table/node/string/snapshot-byte and work/allocation bounds remain effective. Being below a count ceiling does not guarantee enough remaining callback or shared work to complete a call. Catalogue generation overflow marks that catalogue unavailable; it must not stop unrelated vanilla gameplay or silently corrupt the source speaker prototype.

## Errors

Use existing plain `{code,message,field?}` errors; message text is not stable API. Existing peripheral authority/availability precedence and fatal runtime budget controls are unchanged.

| Condition | Result |
| --- | --- |
| Playback rate allowance exhausted after valid arguments | `false`, no dispatch |
| Wrong arity/type, colon call, empty required name/path, or nonfinite number rejected by the existing Data boundary | `E_ARGUMENT` |
| Unknown instrument, invalid sound path, finite out-of-range volume or invalid finite numeric pitch | `E_RANGE` |
| Excessive string/inventory/catalogue/result bounds | `E_LIMIT`, no successful prefix |
| Malformed/ambiguous or unavailable catalogue representation | `E_UNSUPPORTED` |
| Native electrical or operational availability lost | `E_UNPOWERED` except for `getLimits` |
| Bound entity/path/force/surface is no longer authorized | Existing `E_UNREACHABLE` behavior |
| Incomplete or oversized physical proof/adoption | Existing `E_NETWORK_PENDING`, `E_LIMIT` or `E_CAPACITY` as applicable |
| Native sound validation/dispatch fails unexpectedly | `E_ENGINE`; no fabricated success and no automatic replay |
| Callback/shared work or allocation exhausted | Existing fatal `E_BUDGET`, not a retryable false |

Unsupported methods such as `stop` and `playAudio` are absent, not stubs returning success. Unknown addressed methods follow the ordinary peripheral dispatch error contract.

## Example: discover, choose and play

The following uses the canonical saved-program declaration syntax. Ready-to-run alarm, melody and paginated catalogue programs are maintained in `examples/speaker-*.lua` and exercised by the packaged engine fixture.

```lua
function start(event)
  local speaker = peripheral.find("speaker", "red")
  assert(speaker, "Connect a powered vanilla speaker on red")
  for _, instrument in ipairs(speaker.getInstruments()) do
    computer.log(instrument)
  end
  local notes = speaker.getNotes("piano")
  assert(#notes > 0)
  computer.log(notes[1].name)
  computer.log(tostring(speaker.playNote("piano", 0.5, notes[1].pitch)))
  local page = speaker.getSounds("utility/")
  if #page.sounds > 0 then
    computer.log(tostring(speaker.playSound(page.sounds[1], 0.5)))
  end
  computer.setState("speaker", peripheral.getName(speaker))
  computer.every(60, "chime")
end

function chime(event)
  local speaker = peripheral.wrap(computer.getState("speaker"), "red")
  if speaker then
    local accepted = speaker.playNote("piano", 0.25, 0)
    if not accepted then computer.log("Speaker busy this tick") end
  end
end
```

A separate maintained discovery example must store `SoundPage.next` as plain state and fetch at most one page per scheduled callback; never busy-loop through an unknown catalogue or retry playback in the same tick. Acceptance includes the powered path, explicit stop of the example program, power/disconnect errors, actual audible output and the absence of startup replay after cold reload.
