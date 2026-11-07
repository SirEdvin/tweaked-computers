---@meta

---This record describes a native note.
---The containing array is one-based; pitch is zero-based.
---Labels are descriptive and case-sensitive, not MIDI, frequency or portable semitone maps.
---@class TC.NoteInfo
---@field pitch integer Native instrument note index, from zero through note count minus one.
---@field name string Exact native note label. Use discovery instead of hardcoded labels.

---One complete sound-discovery page, without a total count, approximate count or query handle.
---An empty page has sounds={} and no next field.
---Even a full final page omits next.
---@class TC.SoundPage
---@field sounds string[] Unique runtime-valid paths sorted bytewise, at most speaker_sound_page_size.
---@field next? string Last emitted path, only when another matching valid path exists. Pass this value as after.

---This speaker supplies positional audio through the vanilla programmable-speaker prototype, not every entity of its type.
---Calls use checked physical facades.
---Native circuit playback is independent.
---There is no subscription, audio queue, completion event or playback handle.
---There is no stop/playAudio method, arbitrary file/URL loader or new global library.
---
---### Admission versus audibility
---A true playback result means admission and submission to the engine, not audible output.
---A false result means exhaustion of a physical-speaker, computer or world allowance, without dispatch or queueing.
---Every other failure is an error.
---
---Each tick has separate speaker allowances for notes and sounds, and combined computer/world limits.
---Wires, wrappers, saved runs and Console share their identity's credits.
---Zero-volume submissions count.
---Native circuit playback consumes no API quota.
---
---Validation and work occur before dispatch.
---Invalid or refused calls consume no additional playback allowance, but already-spent work remains spent.
---After a dispatch attempt, its quota remains spent even on native error.
---Never automatically retry an uncertain external sound effect.
---Apply, recreation, reconnection and same-tick reload cannot renew existing credits.
---
---Use named timers for later notes.
---Scheduling is not sample-accurate, and the API reports no end time.
---Native mixing can combine or drop accepted sounds.
---Playback is local game-effect audio at the current surface and position of the speaker.
---Playback has no force filter or global fallback.
---
---Charting, listener position and view, sound-specific attenuation, and client mixer/mute settings determine audibility.
---There is no guarantee of an exact native speaker radius, simultaneous voice count or circuit polyphony.
---
---Native condition, instrument, note, global mode and volume-by-signal settings do not control these requests.
---The requests do not rewrite those settings.
---Alerts, settings, wires and power remain unchanged.
---Native circuit audio and GUI/Configurator edits still coexist.
---
---### Availability and lifetime
---Except getLimits, every method requires positive electrical energy and an operational native speaker.
---The speaker must not be disabled, frozen or marked for deconstruction.
---A false circuit playback condition alone is not an outage.
---Every call requires identity, force, surface and selected-wire proof, also for restored Console captures.
---There is no generic lifecycle power polling or missed-note replay.
---
---Stop, outage, removal and disconnection block future requests, not audio after dispatch.
---Cold load and late joining never replay old submissions.
---Persisted identity and admission data is not an audio queue or saved client playback state.
---Facades are not Data.
---
---### Errors
---Wrong types, wrong arity, empty required strings and nonfinite numbers cause E_ARGUMENT.
---An unknown instrument/path or finite volume/pitch outside its domain causes E_RANGE.
---String, inventory, catalogue or result bounds cause E_LIMIT, without a successful prefix.
---A malformed, ambiguous or unavailable catalogue causes E_UNSUPPORTED.
---Native validation or dispatch failure causes E_ENGINE.
---Native outage causes E_UNPOWERED, except for getLimits.
---
---Authority and adoption retain their E_UNREACHABLE, E_NETWORK_PENDING, E_LIMIT and E_CAPACITY rules.
---Host-work exhaustion causes fatal E_BUDGET, not false.
---Existing admission and authority precedence remains.
---Published limits are finite initial envelopes, not measured throughput guarantees.
---Requests below the count limits can still exhaust generic Data or host-work allowances.
---@class TC.Speaker
local Speaker = {}

---Request a native instrument sample independently of circuit playback settings.
---The instrument is the exact discovered name, never a localized or Minecraft alias.
---@param instrument string Nonempty exact installed instrument name within speaker_path_bytes.
---@param volume? number Finite 0..1. Omission or nil defaults to 1. Zero is valid and consumes quota.
---@param pitch? integer Native zero-based note index. Omission or nil defaults to 0. The maximum is the discovered note count minus one.
---@return boolean accepted True after submission. False means playback allowance exhaustion without dispatch or queueing.
function Speaker.playNote(instrument, volume, pitch) end

---Request an engine-valid exact SoundPath, not a raw filename or URL.
---Native validation is the final authority, not a plausible prefix or an old discovery result.
---Valid mod-added paths can play even if discovery does not list them.
---Supported native named/utility/ambient/entity-/tile-/item- path families retain their positional game-effect semantics.
---There is no speed, pitch, duration, loop, position, player or global option.
---This API cannot cancel long samples after submission.
---@param path string Nonempty exact SoundPath within speaker_path_bytes. Preserve case, whitespace and punctuation.
---@param volume? number Finite 0..1. Omission or nil defaults to 1. Zero still consumes quota.
---@return boolean accepted True after submission. False means allowance exhaustion without dispatch.
function Speaker.playSound(path, volume) end

---Read unique exact instrument names in ascending bytewise order.
---Malformed or duplicate native names cause explicit failure, not selection of one name or truncation.
---The method gives no access to files or mutable native catalogue objects.
---@return string[] instruments Exactly one complete detached dense name array.
function Speaker.getInstruments() end

---Read the complete native note order for the selected instrument.
---The result array is one-based.
---playNote can directly use the pitch of each record.
---An unknown instrument causes an error.
---@param instrument string Nonempty exact discovered instrument name within speaker_path_bytes.
---@return TC.NoteInfo[] notes Complete independent native-order records, not a fixed 0..24 range.
function Speaker.getNotes(instrument) end

---Read a page from the captured candidate catalogue through live native validation.
---Capture at this mod's data-final-fixes includes named sounds except private note aliases, and supported utility, ambient, entity, tile and item families.
---The method deduplicates and sorts entries before validation.
---It removes entries that fail runtime validation.
---Later third-party additions are not guaranteed discoverable, although direct playback validates them.
---
---Configuration changes require a fresh traversal for completeness.
---Removed paths can invalidate old pages.
---A missing, oversized, incompatible or malformed catalogue causes an error, not a selected subset.
---Catalogue failure does not disable direct playSound or other services.
---
---Continuation through a fixed catalogue never repeats or skips eligible paths.
---A supplied after need not exist or match prefix.
---The method returns the earliest matches lexically greater than after.
---A change to prefix starts a different traversal, not a saved session.
---Budget failure returns no partial page or false terminal marker.
---Fetch bounded pages through timers, not a busy loop through an unknown catalogue.
---@param prefix? string Literal case-sensitive prefix, not a pattern or glob. Omission or nil defaults to empty.
---@param after? string Exclusive bytewise lower bound, not a numeric offset. Omission or nil defaults to empty. Both strings obey speaker_path_bytes.
---@return TC.SoundPage page One complete validated page with an accurate optional continuation.
function Speaker.getSounds(prefix, after) end

---Read the effective common and speaker-specific limits, even without native power.
---Exact physical reachability and generation checks still apply.
---@return TC.SpeakerLimits limits One defensive current limit map.
function Speaker.getLimits() end
