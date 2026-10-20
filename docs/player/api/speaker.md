# Programmable speaker

Use the existing vanilla `programmable-speaker`, with no adapter item, replacement, research or helper entity. Connect its native red or green socket to your computer Network. Discovery is same-force, same-surface and same-color: `peripheral.find("speaker", "red")`. A speaker can relay physical discovery on one color, even without power, but never bridges colors or makes a pole/ordinary machine a supported relay. Connected pre-existing speakers are adopted in bounded maintenance; retry `E_NETWORK_PENDING` on a later tick. Capacity refusal leaves the speaker and its wires intact. Other modded speaker names are not supported.

Registration preserves the native speaker GUI, settings, alerts, electrical behavior, native circuit playback, wires, blueprint settings and mining result. Configurator can still read/write the registered speaker through its separate Targets network. API playback does not alter the native circuit condition, instrument/note, playback mode, volume-by-signal or polyphony settings. A false circuit condition alone does not prevent API notes.

## Calls and returns

Calls are synchronous dot calls. Explicit nil in an optional position is omission. Extra arguments, colon receivers and options tables are errors. The exact methods are these six; there is no `playAudio`, `stop`, streaming, speed control, completion event or playback queue.

### getInstruments()

Returns one defensive complete dense array of exact instrument names in ascending bytewise order. Names are case-sensitive Factorio names, such as `piano`, `drum-kit` and `alarms`, not Minecraft aliases. Oversized, malformed or ambiguous catalogues fail explicitly instead of returning a partial instrument list.

### getNotes(instrument)

Returns one complete dense array of `{pitch=integer, name=string}` in native note order. Pitch is a zero-based Factorio sample index; the surrounding Lua array is one-based. The first pinned piano sample is `{pitch=0, name="F3"}`. Discover the range for each instrument: indices are not MIDI numbers, frequencies or a universal CC `0..24` range. Mutating the result cannot change playback metadata.

### playNote(instrument [, volume [, pitch]])

Returns exactly one boolean. Instrument must be an exact discovered name. Volume is finite in `[0,1]`, default `1`; pitch is a finite integer from zero through that instrument's note count minus one, default `0`. It plays a private local sound alias referencing the existing installed sample, independently of native circuit settings. Zero volume is valid and spends the same playback allowance.

### playSound(path [, volume])

Returns exactly one boolean. Path is an exact nonempty engine-valid SoundPath, at most 256 bytes. Volume has the same range/default as `playNote`. Named sounds and native `utility/`, `ambient/`, `entity-*`, `tile-*` and `item-*` paths are supported where the engine validates them. Filenames, URLs, raw samples and arbitrary files are not an audio loader. Direct validation can accept paths registered after discovery's capture point.

### getSounds([prefix [, after]])

Returns one `{sounds={...}, next=optional_string}`. At most 50 unique runtime-valid paths appear, in ascending bytewise order. Prefix and after default to empty strings and are at most 256 bytes. Prefix is literal and case-sensitive, not a pattern. After is an exclusive lexical lower bound; it need not be a known path or share the prefix. Pass `next` as the next `after` using the same prefix. Next is present only when a later valid match exists and equals the last returned path. An empty terminal page is `{sounds={}}`; a terminal full page also omits next. There is no total, numeric offset, live iterator or saved cursor session.

The bounded catalogue captures candidates from named sounds and documented utility, ambient, entity, tile and item sound fields at this mod's data-final-fixes stage, after declared dependencies. Private note aliases are excluded. Later third-party additions are not promised discoverable; direct playback still validates them. Restart a full traversal after changing mods. Runtime-invalid paths are omitted; budget refusal returns no partial page. A missing/oversized/incompatible catalogue reports a typed error rather than a curated subset. Fetch at most one page per callback, as in the maintained catalogue example.

### getLimits()

Returns a defensive map of current common limits plus the following speaker limits. It remains callable without electrical power when the exact speaker is still physically reachable.

| Field | Initial value |
| --- | --- |
| `speaker_path_bytes` | 256 |
| `speaker_instruments` | 64 |
| `speaker_notes_per_instrument` | 128 |
| `speaker_sound_page_size` | 50 |
| `speaker_sound_catalog_entries` | 32768 |
| `speaker_notes_per_tick` | 8 |
| `speaker_sounds_per_tick` | 1 |
| `speaker_computer_submissions_per_tick` | 16 |
| `speaker_world_submissions_per_tick` | 64 |

Names fit the same 256-byte limit. Common Data/snapshot/work/allocation budgets still apply; count ceilings do not guarantee enough remaining work or simultaneous saturation. Discovery materializes only pre-admitted bounded metadata blocks, not one giant runtime catalogue.

## Admission, power and audible output

True means accepted engine submission, not an audible acknowledgement. False means an exhausted physical-speaker note/effect allowance, computer combined allowance or world combined allowance. A refused call submits nothing and queues nothing. Both colors, multiple computers, programs and Console calls share the applicable counters. Invalid arguments spend validation work but no playback quota. Zero-volume submissions spend quota. Engine failure retains spent allowance; never automatically retry an uncertain effect. Apply, wrapper recreation, reconnect, caught errors and same-tick reload do not reset credits. Only a genuinely later simulation tick renews them.

Except getLimits, calls require positive native electrical energy and no script-disable, freezing or deconstruction. These conditions report `E_UNPOWERED`; a false circuit trigger alone does not. Every effect reproves exact identity, force, surface and physical wire authority. Replacement entities get distinct names; retained stale bindings fail closed.

In pinned Factorio 2.0.77, the vanilla speaker reports `is_freezable=false` even on Aquilo despite its heating metadata. Registration preserves that native capability; it does not manufacture freezing or add a heater. The defensive frozen-state check applies only when the engine actually exposes such a state.

Both methods submit once at the speaker's current position and surface using the game-effect mixer. Nearby players on any force are eligible under engine charting, camera/listener position, sound-specific attenuation, mixer/polyphony and client mute settings. Hearing grants no control authority. Native global/surface mode does not broaden API playback. Note aliases do not promise the native circuit speaker's exact audible radius or polyphony. Simulation timers are not sample-accurate sequencing. Stop, outage, detach and destruction prevent new calls but cannot cancel already submitted long samples. Reload or late join does not replay old submissions, and continuation of already audible samples is not promised.

Wrong arity/types, empty names/paths and nonfinite Data are `E_ARGUMENT`; unknown names/paths or finite invalid volume/pitch are `E_RANGE`; excessive bounds are `E_LIMIT`; incompatible catalogues/state are `E_UNSUPPORTED`; unexpected native validation/dispatch failures are `E_ENGINE`. Existing `E_UNREACHABLE`, `E_NETWORK_PENDING`, `E_CAPACITY` and fatal `E_BUDGET` contracts still apply. Work and the immediate boolean return are admitted before an irreversible audio dispatch; a later independent guest operation can still exhaust its own budget.

## Programs, installation and rollback

Use the [alarm, melody and paginated catalogue programs](../examples.md). Save names/wires and plain state, not callback-local facade objects. Rewrap on each callback. Saved programs and explicit Console commands use the same provider and admission ledger; Console does not provide background timers.

Already-connected speakers are adopted without replacement, a world scan or startup audio. Identities, settings, wires and spent counters survive ordinary reload; no audio queue is persisted. Back up the prior save and mod set before installation. Restoring both is the supported rollback: an older mod is not promised to understand newer registry records, so do not test a live downgrade on your campaign.
