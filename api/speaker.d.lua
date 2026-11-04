---@meta

---Native note record. The containing array is one-based, pitch is zero-based.
---Labels are descriptive/case-sensitive, not MIDI/frequency/portable semitone maps.
---@class TC.NoteInfo
---@field pitch integer Native instrument note index, from zero through note count minus one.
---@field name string Exact native note label; discover rather than hardcode labels.

---One complete sound-discovery page; no total/approximate count or query handle.
---Empty means sounds={} with next absent. Even a full final page omits next.
---@class TC.SoundPage
---@field sounds string[] Unique runtime-valid paths sorted bytewise, at most speaker_sound_page_size.
---@field next? string Last emitted path only when another matching valid path exists; pass as after.

---Positional audio through the vanilla programmable-speaker prototype, not every
---entity of its type. Calls use checked physical facades; native circuit playback
---is independent. No subscription, audio queue, completion event, playback handle,
---stop/playAudio method, arbitrary file/URL loader or new global library exists.
---
---### Admission versus audibility
---Playback true means admitted and submitted to the engine, not heard. False means
---a physical-speaker, computer or world allowance was exhausted, without dispatch
---or queueing. Every other failure is an error. Each tick has separate note/sound
---speaker allowances and combined computer/world limits; wires, wrappers, saved
---runs and Console share their identity's credits. Zero-volume submissions count.
---Native circuit playback consumes no API quota. Validation/work happens before
---dispatch; invalid/refused calls consume no additional playback allowance, but
---already-spent work remains spent. Once dispatch is attempted, its quota remains
---spent even on native error; never auto-retry an uncertain external sound effect.
---Apply/recreation/reconnection/same-tick reload cannot renew existing credits.
---
---Use named timers for later notes. Scheduling is not sample-accurate and no end
---time is reported. Native mixing may combine/drop accepted sounds. Playback is
---local game-effect audio at the speaker's current surface/position, not force-
---filtered and never a global fallback. Charting/listener position/view, sound-
---specific attenuation and client mixer/mute settings decide audibility. No exact
---native speaker radius, simultaneous voice count or circuit polyphony guarantee.
---Native condition/instrument/note/global mode/volume-by-signal settings neither
---control nor get rewritten by these requests. Alerts/settings/wires/power remain
---unchanged; native circuit audio and GUI/Configurator edits still coexist.
---
---### Availability and lifetime
---Except getLimits, every method requires positive electrical energy and an
---operational, non-disabled/non-frozen/not-marked-for-deconstruction native speaker.
---A false circuit playback condition alone is not an outage. Identity/force/surface/
---selected-wire proof applies to every call, including restored Console captures.
---No generic lifecycle power polling or missed-note replay is introduced. Stop,
---outage/removal/disconnection blocks future requests, not already-dispatched audio.
---Cold load/late joining never replay old submissions. Persisted identity/admission
---data is not an audio queue or saved client playback state. Facades are not Data.
---
---### Errors
---Wrong types/arity/empty required strings/nonfinite numbers: E_ARGUMENT. Unknown
---instrument/path or finite volume/pitch outside domain: E_RANGE. String/inventory/
---catalogue/result bounds: E_LIMIT, no successful prefix. Malformed/ambiguous or
---unavailable catalogue: E_UNSUPPORTED. Native validation/dispatch failure: E_ENGINE.
---Native outage: E_UNPOWERED except getLimits. Authority/adoption retain their
---E_UNREACHABLE/E_NETWORK_PENDING/E_LIMIT/E_CAPACITY rules. Work/allocation exhaustion
---is fatal E_BUDGET, not false. Existing admission/authority precedence remains.
---Published limits are finite initial envelopes, not measured throughput promises;
---below-count requests can still exhaust generic Data/work/allocation allowances.
---@class TC.Speaker
local Speaker = {}

---Request a native instrument sample independently of circuit playback settings.
---Instrument is the exact discovered name, never a localized/Minecraft alias.
---@param instrument string Nonempty exact installed instrument name within speaker_path_bytes.
---@param volume? number Finite 0..1; omitted/nil defaults 1. Zero is valid and consumes quota.
---@param pitch? integer Native zero-based note index; omitted/nil defaults 0, maximum discovered note count minus one.
---@return boolean accepted True submitted; false playback allowance exhausted without dispatch/queue.
function Speaker.playNote(instrument, volume, pitch) end

---Request an engine-valid exact SoundPath, not a raw filename or URL. Native
---validation is final authority, not a plausible prefix or old discovery result.
---Valid mod-added paths can play even if absent from discovery. Supported native
---named/utility/ambient/entity-/tile-/item- path families retain their positional
---game-effect semantics. No speed/pitch/duration/loop/position/player/global option
---exists; already submitted long samples cannot be cancelled by this API.
---@param path string Nonempty exact case/whitespace/punctuation-preserving SoundPath within speaker_path_bytes.
---@param volume? number Finite 0..1; omitted/nil defaults 1, zero still consumes quota.
---@return boolean accepted True submitted; false allowance exhaustion with no dispatch.
function Speaker.playSound(path, volume) end

---Read unique exact instrument names in ascending bytewise order. Malformed or
---duplicate native names fail explicitly, never choose one or truncate. No files
---or mutable native catalogue objects are exposed.
---@return string[] instruments Exactly one complete detached dense name array.
function Speaker.getInstruments() end

---Read the selected instrument's complete native note order. Result array is
---one-based; each record's pitch is directly usable by playNote. Unknown is error.
---@param instrument string Nonempty exact discovered instrument name within speaker_path_bytes.
---@return TC.NoteInfo[] notes Complete independent native-order records, not a fixed 0..24 range.
function Speaker.getNotes(instrument) end

---Page the captured candidate catalogue through live native validation. Capture
---at this mod's data-final-fixes includes named sounds except private note aliases,
---and supported utility/ambient/entity/tile/item families. Deduplicate/sort before
---validation; runtime-invalid entries disappear. Later third-party additions are
---not promised discoverable, although direct playback validates them. Configuration
---changes require a fresh traversal for completeness; removed paths can invalidate
---old pages. Missing/oversized/incompatible/malformed catalogue is an error, not a
---curated subset; its failure does not disable direct playSound or other services.
---Fixed-catalogue continuation never repeats/skips eligible paths. A supplied after
---need not exist or match prefix; return earliest matches lexically greater than it.
---Changing prefix starts a different traversal, not a saved session. Budget failure
---returns no partial page or false terminal marker. Fetch bounded pages via timers,
---not an unknown-catalogue busy loop.
---@param prefix? string Literal case-sensitive prefix, not a pattern/glob; omitted/nil defaults empty.
---@param after? string Exclusive bytewise lower bound, not numeric offset; omitted/nil defaults empty. Both strings obey speaker_path_bytes.
---@return TC.SoundPage page One complete validated page and truthful optional continuation.
function Speaker.getSounds(prefix, after) end

---Read effective common and speaker-specific limits, even when native power is
---absent. Exact physical reachability/generation checks still apply.
---@return TC.SpeakerLimits limits One defensive current limit map.
function Speaker.getLimits() end
