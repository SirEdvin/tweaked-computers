# Programmable speaker

Use the vanilla `programmable-speaker`, with no adapter, replacement, research or helper entity. Connect its red or green socket to your computer Network and use `peripheral.find("speaker", "red")`. Discovery is same-force, same-surface and same-color. A speaker relays physical discovery on one color, even without power; it never bridges colors. Connected pre-existing speakers are adopted by maintenance. `E_NETWORK_PENDING` means adoption/proof is not yet complete; resource refusal leaves the native speaker and wires intact. Other modded speaker names are not supported.

Registration preserves the native GUI, settings, alerts, electrical behavior, circuit playback, wires, blueprints and mining result. Configurator can still access the native speaker through its Targets network. API playback does not alter circuit conditions, instrument, playback mode, volume-by-signal or polyphony. A false circuit condition alone does not prevent API notes.

## Calls and returns

Calls use dots. Explicit nil in an optional position is omission. Extra arguments, colon receivers and options tables are errors. The six methods below do not expose streaming, speed control, completion events, playback handles or a public future API. Work pressure can pause the calling invocation before it returns.

### getInstruments()

Returns one defensive complete dense array of exact instrument names in ascending bytewise order. Names are case-sensitive installed Factorio names, such as `piano`, `drum-kit` and `alarms`, not Minecraft aliases. There is no mod-imposed instrument-count or name-length ceiling. Malformed or ambiguous metadata fails explicitly rather than returning a curated subset. Retaining the result must fit resource policy.

### getNotes(instrument)

Returns a complete dense array of `{pitch=integer, name=string}` in native note order. Pitch is a zero-based installed sample index; the Lua array is one-based. The first pinned piano sample is `{pitch=0, name="F3"}`. Discover each instrument's range: indices are not MIDI numbers, frequencies or a universal `0..24` range. Mutating results cannot change playback metadata. There is no independent 128-note ceiling.

### playNote(instrument [, volume [, pitch]])

Returns exactly one boolean. Instrument must be an exact discovered name. Volume is finite in `[0,1]`, default `1`; pitch is an integer from zero through that instrument's native note count minus one, default `0`. Submission uses a private local alias referencing the installed sample, independently of circuit settings. Zero volume is valid.

### playSound(path [, volume])

Returns exactly one boolean. Path is an exact nonempty engine-valid SoundPath; there is no separate 256-byte mod ceiling. Volume has the same range and default as `playNote`. Named sounds and native `utility/`, `ambient/`, `entity-*`, `tile-*` and `item-*` paths are supported where the engine validates them. Filenames, URLs and raw samples are not an audio loader. Direct validation can accept paths registered after discovery's capture point.

### getSounds([prefix [, after]])

Returns `{sounds={...}, next=optional_string}`. The effective `speaker_sound_page_size` setting controls the maximum number of unique runtime-valid paths per page (default **50**). Prefix and after default to empty strings. Prefix is literal, case-sensitive and not a pattern. After is an exclusive lexical lower bound; it need not be a known path or share the prefix.

Pass `next` as the next `after` with the same prefix. Next is present only when a later valid match exists and equals the last returned path. An empty terminal page is `{sounds={}}`; a terminal full page also omits next. Changing page size does not invalidate the lexical cursor. A suspended page uses the page size accepted when that call began. No numeric offset or public saved cursor session is created.

Discovery captures complete candidates from named sounds and documented utility, ambient, entity, tile and item sound families at data-final-fixes, after declared dependencies. It has no total catalogue-count ceiling. Internal metadata chunks are not a public page or catalogue limit. Private note aliases are excluded. Later third-party additions may be directly playable without appearing in discovery; restart traversal after changing mods.

Runtime-invalid paths are omitted. A private saved scan cursor retains a partially prepared page across work suspension and cold load; only a complete page is returned. Missing or incompatible metadata reports a typed error, not a fabricated terminal page. The maintained catalogue example traverses pages using `next`.

### getLimits()

Returns a defensive table with `policy_version=2`, `resources` and `tuning`.
Read the page size as `speaker.getLimits().tuning.speaker_sound_page_size.limit`
(default 50), not as a top-level field. Resource entries identify the effective
`limit`, `unit`, `scope`, `setting` and exhaustion `behavior`; tuning entries use
`kind="tuning"` instead of an exhaustion behavior. The speaker reports shared
callback work/allocation, host work, runtime/host memory, pending-work storage and
host-stack depth settings, not unrelated KV or monitor settings. This is a
breaking introspection change; the other method result shapes are unchanged.
Removed instrument, note, path, catalogue and per-tick submission ceilings are
not advertised. It remains callable without electrical power when the exact
speaker is physically reachable.

## Admission, power and audible output

**True means the engine submission call completed, not that anybody heard it.** Playback no longer returns false because an invented per-speaker, per-computer or world submission count was reached. Host work and result storage are admitted before the native effect. Work pressure waits before submission; retained-resource exhaustion is a recoverable refusal. Callers must not replay submissions on an assumed quota timeout.

A private attempted flag and the prepaid result prevent the same call from resubmitting after cold load. Native failure reports `E_ENGINE` and is never automatically retried: an uncertain native effect is not safe to repeat. There is no application audio queue, acknowledgement or guarantee that previously audible samples continue through reload or late join.

Except `getLimits`, calls require native electrical energy and no script-disable, freezing or deconstruction; otherwise `E_UNPOWERED`. Every effect reproves exact identity, force, surface and physical wire authority immediately before submission. Replacement entities have distinct names and stale bindings fail closed. In pinned Factorio 2.0.77 the vanilla speaker reports `is_freezable=false` even on Aquilo; integration does not manufacture freezing or add a heater.

Both playback methods submit at the speaker's current position and surface using the game-effect mixer. Actual audibility depends on engine charting, camera/listener position, attenuation, mixer/polyphony and mute settings. Hearing grants no control authority. Native global/surface mode does not broaden API playback. Aliases do not promise the native circuit speaker's exact audible radius or polyphony. Timers are not sample-accurate. Stop, outage, detach and destruction prevent new calls but cannot cancel samples already submitted.

Wrong arity/types, empty names/paths and nonfinite values are `E_ARGUMENT`; unknown names/paths or invalid finite volume/pitch are `E_RANGE`; incompatible catalogues are `E_UNSUPPORTED`; native validation/dispatch failures are `E_ENGINE`. Existing physical-authority errors still apply. Memory refusal preserves accepted state; a later independent operation may wait or refuse its own resources after a successful submission.

## Programs, installation and rollback

Use the [alarm, melody and paginated catalogue programs](../examples.md). Saved programs and explicit Console commands share the same resource-governed provider; Console does not supply background timers. Already-connected speakers are adopted without replacement, a world scan or startup audio. Back up the save and complete mod set before installation; restoring both is the supported rollback, not downgrading a live campaign.
