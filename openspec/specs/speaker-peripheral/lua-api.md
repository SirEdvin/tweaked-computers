# Speaker Lua API v1

This is the normative API companion to [the speaker capability](spec.md) for the active development candidate, not a published release. Existing common Data, budget, authority and saved-program/Console rules continue to apply.

## Discovery and method inventory

Peripheral type: `speaker`. The supported carrier is the vanilla entity named `programmable-speaker`, not every prototype of that entity type. Use `peripheral.find("speaker", "red")`, `wrap(name, wire)` or `call(name, wire, method, ...)`; the wire is always explicitly `"red"` or `"green"`.

The exact public method set is `getInstruments`, `getLimits`, `getNotes`, `getSounds`, `playNote`, `playSound`. Calls retain sequential dot-call semantics, but resource pressure may suspend the private continuation before a call returns. There is no speaker subscription, application audio queue, completion event or special global speaker library. Existing attach/detach events use `peripheral_type="speaker"`. Resource-policy implementation and acceptance remain tracked in the repository's `docs/resource-policy-validation.md` (not bundled); this contract is not a claim that all gates have passed.

| Signature | Exact returns |
| --- | --- |
| `speaker.playNote(instrument [, volume [, pitch]])` | Exactly one boolean admission result |
| `speaker.playSound(path [, volume])` | Exactly one boolean admission result |
| `speaker.getInstruments()` | Exactly one complete dense string array |
| `speaker.getNotes(instrument)` | Exactly one complete dense `NoteInfo[]` |
| `speaker.getSounds([prefix [, after]])` | Exactly one `SoundPage` |
| `speaker.getLimits()` | Exactly one defensive policy-v2 table with `resources` and `tuning` maps |

`playNote` accepts one, two or three arguments; `playSound` one or two; `getNotes` exactly one; `getSounds` zero, one or two; the other methods zero. Explicit nil in an optional position is the same as omission. Extra arguments, colon-call receivers and option tables are rejected, not ignored.

## Notes

- `instrument` is an exact case-sensitive instrument name from `getInstruments`, for example `piano`, `drum-kit` or `alarms`. Localized display text and Minecraft instrument aliases are not accepted.
- `volume` is a finite number in `[0,1]`, default `1`. It multiplies the sample's defined volume; the client mixer and native attenuation still apply. Zero is a valid silent submission and consumes normal work credits.
- `pitch` is a finite integer from `0` through the selected instrument's note count minus one, default `0`. It is the zero-based Factorio note index. It is not a frequency, MIDI number or universally meaningful semitone offset, and there is no fixed CC:Tweaked `0..24` range.
- `getInstruments()` returns unique names in ascending bytewise order.
- `getNotes(instrument)` returns records in native note order. Each record has exactly `pitch:integer` and `name:string`. Its `pitch` can be passed directly to `playNote`; the surrounding Lua result array remains one-based.
- Note labels are descriptive and case-sensitive. For example, the first piano sample in the pinned base catalogue is labelled `F3` and has pitch `0`; programs should discover rather than hardcode a label-to-index map.
- Inventories are copied plain data. No sound filename, native prototype object or mutable host catalogue is exposed. Duplicate instrument names, malformed definitions or unrepresentable metadata fail explicitly rather than selecting an arbitrary duplicate or truncating the inventory.

The notes service uses Factorio's existing instrument sample definitions independently of the speaker's native circuit-triggered playback settings. The native circuit condition, selected instrument/note, volume-by-signal, global/surface mode and allow-polyphony setting are not controls for the API request. Those settings are neither permanently rewritten nor used to broadcast API audio. Native circuit playback can still run alongside API audio.

## Sound paths

`playSound(path [, volume])` requests an engine-valid `SoundPath` at the speaker's location. Volume has the same range and default as `playNote`. `path` must be an exact nonempty string; whitespace, case and punctuation are never normalized. No independent mod path-length ceiling applies.

Accepted path families are those supported by Factorio 2.0.77, including named sound prototypes and valid `utility/`, `ambient/`, `entity-*`, `tile-*` and `item-*` sound paths. Native validation is the final authority: a plausible prefix or a name in an old catalogue is not enough. A valid path added by another mod can be played directly even when absent from discovery. Paths are sound identifiers, not permission to read arbitrary files or fetch URLs. Passing a raw game/mod filename is not an alternate audio loader.

There is no speed/pitch argument, duration argument, looping flag, caller-chosen position/surface, target-player list or global-mode flag. An already submitted long sample is not cancellable through this API.

## Sound discovery

`getSounds([prefix [, after]])` returns:

- `sounds`: a dense array of unique runtime-valid sound-path strings, in ascending bytewise order, with at most `speaker_sound_page_size` entries.
- `next`: optional string. Present only when another matching valid catalogue path exists. Pass it as `after` to fetch the next page. It is the last emitted path, not a numeric offset, live iterator or stored query session.

There is no `total` or approximate count. An empty result is `{sounds={}}`, with `next` absent. A full page with no remaining match also omits `next`. In a fixed catalogue, continuation never duplicates a returned path or skips an eligible path.

`prefix` defaults to the empty string and is a literal case-sensitive prefix, not a Lua pattern or glob. `after` defaults to the empty string and is an exclusive bytewise lower bound. Both can be empty without an independent mod length ceiling; a supplied lower-bound key need not exist or share the prefix. The next page is the earliest matching valid paths lexically greater than `after`. Changing filters begins a different traversal; there is no hidden cursor authority or expiration. Page size is configurable tuning: a suspended call retains its accepted page size, and changing it does not invalidate the lexical cursor.

Discovery indexes the following candidates visible at this mod's `data-final-fixes` capture point:

- Named `sound` prototypes, excluding this feature's private generated note aliases.
- Utility and ambient paths identified by the pinned path rules.
- Applicable entity, tile and item path families identified by those rules.

Candidate entries are deduplicated and sorted. Runtime-invalid candidates are not returned. With the supported base-only and Space Age mod sets, paging the catalogue covers all valid candidates from these families. Third-party additions after this mod's capture point are not promised discoverable; direct `playSound` still validates them. Removing a prototype can invalidate an old returned path. Treat a changed mod configuration as a new catalogue and restart traversal if a complete new inventory is required.

A missing, incompatible or malformed catalogue returns a typed error, not an undocumented curated subset. Catalogue/instrument/note counts are not capacity ceilings. Aggregate resource refusal returns no successful prefix; ordinary work exhaustion suspends page preparation without returning a partial page or fabricated terminal marker. Catalogue failure does not by itself disable direct validation/playback of sound paths or unrelated peripherals.

## Admission, timing and audibility

Both playback methods return `true` only when the host has admitted the request and submitted it to the engine. They do not return false because an old note/sound/submission-count quota was reached. Work exhaustion suspends before submission; hard-resource/native refusal raises a recoverable typed error. The return value never depends on a particular player's position, mute setting, rendered audio or whether a client exists.

Calls share the applicable computer and world resource budgets, including program and Console work on the same computer. There are no separate physical-speaker note/sound or computer/world submission-count quotas. Wrapper recreation, wire-color changes and different speakers do not renew the applicable work credits.

Validation, outcome-record storage and result admission occur before audio dispatch. Already spent validation/work credits remain spent after refusal. Once dispatch is attempted, the same call cannot automatically retry an uncertain external audio effect, including after native failure or cold reload. Only an unsubmitted continuation may resume after admission and live authority revalidation. Stop cancels unsubmitted work without recalling previously submitted sound. Same-tick reload must not renew computer/world work credits.

Use named timers for later notes. The API does not buffer a song, guarantee sample-accurate timing or report when a note finishes. Simulation scheduling and client audio rendering are different clocks. Native mixer/aggregation limits can drop or combine accepted sounds; `true` is not proof of audible delivery or an exact simultaneous-voice count.

Audio is positional on the speaker's current surface, not force-filtered. The engine's charting, listener position/view, sound-specific attenuation and audio settings determine what is actually heard. Note playback uses local game-effect samples; it does not promise the native speaker entity's exact audible radius or native circuit polyphony settings. Other sound paths retain their sound-specific spatial behavior under a positional game-effect request. No global fallback is permitted if a sound cannot satisfy local playback; engine acceptance must cover the documented supported path families.

## Availability, identity and native coexistence

- `getLimits` works whenever the exact peripheral remains reachable, including when unpowered. Every other method requires live availability, matching existing peripheral conventions.
- The speaker must retain positive native electrical energy and must not be script-disabled, frozen or marked for deconstruction. A false circuit playback condition alone is not an API outage. Unavailable service reports `E_UNPOWERED`; discovery and same-color relay remain intact.
- Every call reproves exact identity, force, surface and selected wire. Stale wrappers cannot control replacements; coordinates and labels remain descriptive only.
- Native circuit playback is independent of API work accounting. Native GUI and Configurator edits remain available. No API call changes alerts, circuit settings, native volume, playback mode, wires, power buffers or energy consumption.
- Stop, disconnect, outage and destruction prevent subsequent unauthorized submissions but do not promise cancellation of samples already dispatched. Reload and late joining do not replay old submissions. The feature persists admission/identity data only, not audio queues or client playback state.
- Standard program facades are callback-local and cannot be stored as Data. Store the peripheral name and wire, then wrap again. Existing Console symbolic bindings remain supported with the same live checks; they add no background playback loop.

## Limits

`getLimits()` returns `{policy_version=2, resources={...}, tuning={...}}`. This is
a breaking introspection change; method inventory and other result shapes are
unchanged. Each resource entry contains `limit`, `unit`, `scope`, `setting` and
`behavior`. The applicable entries are `callback_work`, `callback_allocations`,
`host_work_per_tick`, `runtime_memory_bytes`, `host_memory_bytes`,
`pending_work_bytes` and `host_stack_depth`; these refer to shared owner budgets,
not per-speaker quotas. Defaults and live values come from the resource-policy
settings registry, not duplicated speaker constants.

`tuning.speaker_sound_page_size` has `limit` (default 50), `unit="records"`,
`scope="page"`, `setting="tc-speaker-sound-page-size"` and `kind="tuning"`.
Read the maximum page length as `s.getLimits().tuning.speaker_sound_page_size.limit`.
There is no top-level page-size field or advertised path, catalogue, instrument,
note, submission-count, generic table-entry or network-node quota. Unrelated KV
and monitor settings are omitted. Editing any returned entry cannot alter the
host policy. Available resource headroom is not a measured throughput promise.

## Errors

Use existing plain `{code,message,field?}` errors; message text is not stable API. Resource errors additionally identify the resource, setting, usage, requested growth and effective limit. Existing peripheral authority/availability precedence is unchanged. Private work suspension and Stop are not guest-catchable errors.

| Condition | Result |
| --- | --- |
| Ordinary work slice exhausted before submission | Private suspension, no dispatch until resumed admission |
| Wrong arity/type, colon call, empty required name/path, or nonfinite number rejected by the existing Data boundary | `E_ARGUMENT` |
| Unknown instrument, invalid sound path, finite out-of-range volume or invalid finite numeric pitch | `E_RANGE` |
| Aggregate retained-resource capacity exhausted | Recoverable resource error, no successful prefix or submission |
| Malformed/ambiguous or unavailable catalogue representation | `E_UNSUPPORTED` |
| Native electrical or operational availability lost | `E_UNPOWERED` except for `getLimits` |
| Bound entity/path/force/surface is no longer authorized | Existing `E_UNREACHABLE` behavior |
| Incomplete or oversized physical proof/adoption | Existing `E_NETWORK_PENDING`, `E_LIMIT` or `E_CAPACITY` as applicable |
| Native sound validation/dispatch fails unexpectedly | `E_ENGINE`; no fabricated success and no automatic replay |
| Indivisible native catalogue copy or path operation cannot fit a fresh configured slice | Recoverable `E_CAPACITY` before the native call, identifying the callback or shared host work setting; not endless suspension or a retryable false |

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
    assert(speaker.playNote("piano", 0.25, 0))
  end
end
```

The maintained discovery example stores `SoundPage.next` as plain state and fetches one page per scheduled callback. Do not replay a successful or uncertain native submission on an assumed quota timeout. Acceptance includes the powered path, explicit stop of the example program, power/disconnect errors, actual audible output and the absence of startup replay after cold reload; the validation report distinguishes completed checks from these remaining gates.
