# Design

## Context

See `proposal.md` for motivation and confirmed gameplay choices. This document is a planning artifact: source/API inspection has been performed, but no new implementation, native audio, performance or multiplayer gate has run.

Relevant observed constraints:

- `info.json` pins base and optional Space Age to 2.0.77. Version-labelled runtime/prototype JSON is available in the supplied licensed distribution under `gameitself/base-2.0.77/factorio/doc-html/`.
- `scripts/services/peripheral.lua` has a closed family registry, exact identity/generation and physical-path checks, availability hooks, guarded facades and attachment notifications. Its metadata construction dereferences `defs.devices[rec.kind]` before a provider's `describe` hook, so a new native kind needs an earlier metadata branch.
- `scripts/network.lua` currently accepts only registered composite network vertices. `scripts/registry.lua` already allocates opaque non-reused identities, records exact native entities and shares identity across colors.
- `scripts/lifecycle.lua` assumes generated composite shells: it disables combinator behavior, creates private power entities, normalizes power, upgrades legacy bodies and can destroy/refund refused placements. `scripts/device-art.lua` expects authored status sprites. None is appropriate for an observed vanilla speaker without an explicit native-carrier branch.
- `scripts/blueprints.lua:15` rewrites registered bodies as mod shells and omits registered non-body entries; native speakers need preservation in mixed selections, not just an early return in an isolated-speaker test.
- `scripts/configuration/targets.lua:29` currently marks every registered entity protected. Without changing that ownership distinction, adding a speaker to the registry would silently remove its existing Configurator support. Existing instrument/note validation lives in `scripts/configuration/adapters.lua`.
- Native GUI filtering in `scripts/ui/interaction.lua` is currently restricted to authored shells and helper names; keep speakers outside that filter. Native placement, recipe, speaker GUI and samples already exist.
- The pinned API has `LuaEntity.play_note`, `LuaEntity.parameters`, `LuaEntityPrototype.instruments`, `LuaSurface.play_sound`, `LuaHelpers.is_valid_sound_path`, `LuaPrototypes.mod_data` and `LuaModData.data`. It has no runtime `prototypes.sound` registry or generic audio-stop/buffer API. `PlaySoundSpecification` supports position, volume and mixer override, not runtime sound speed.
- `scripts/runtime/sandbox.lua:262` copies service results after host invocation, and copying even a boolean spends work. Irreversible audio dispatch must not be followed by an avoidable return-copy budget failure. `scripts/runtime/admission.lua` already establishes persisted tick/identity accounting semantics.
- The unimplemented radar change proposes similar native-carrier adoption and modifies some of the same network requirements. Inspector and documentation changes are also present. They are coordination inputs, not implemented dependencies or authorization to edit their artifacts.

Primary references inspected:

- `https://tweaked.cc/peripheral/speaker.html`: names and compatibility boundaries, not a promise of identical sound sets or streaming support.
- `gameitself/base-2.0.77/factorio/doc-html/runtime-api.json`: the exact classes/concepts above, including `ProgrammableSpeakerPlaybackMode` and all supported `SoundPath` families.
- `gameitself/base-2.0.77/factorio/doc-html/prototype-api.json`: `ProgrammableSpeakerPrototype`, `SoundPrototype`, `Sound`, `SoundDefinition` and `ModData`.
- `gameitself/base-2.0.77/factorio/data/base/prototypes/entity/circuit-network.lua`: actual instrument and note sample definitions.

No distribution, sound file or other game asset is to be copied into the mod or committed.

## Goals / Non-Goals

Goals:

- Add one native carrier and one reviewed peripheral service while reusing existing identities, authority, snapshots, scheduler work limits and native assets.
- Keep factory circuit playback, peripheral topology and program-requested audio independent, with clear shared admission rather than per-wrapper hidden ownership.
- Use one positional playback backend for both methods, so native global/volume-by-signal settings never leak into API playback.
- Resolve catalogue generation, bounded runtime materialization and exact artifact/test integration during planning rather than leaving an open-ended architecture task.

Non-goals:

- No general plugin framework, generic native-peripheral compatibility registry, async audio scheduler, audio-duration tracker or hidden external player/service.
- No change to the six authored device prototypes, artwork or program execution model; no permanent settings enforcement on speakers.
- No claim that source inspection, silent headless tests or an engine submission proves audible delivery, precise playback timing or real-client multiplayer behavior.

## Decisions

### 1. A narrow native-speaker carrier, not another composite

Add a focused host-only carrier adapter, proposed as `scripts/speaker.lua`, and provider `scripts/services/speaker.lua`. These paths are proposed additions. Keep the supported native name `programmable-speaker` separate from `defs.order` and the prototype-generation loop. Register an internal speaker kind using the existing registry, with an explicit native-carrier marker, exact body, no owned children and public type `speaker`.

Compose dispatch through the existing event owner; do not add a second registration that replaces current lifecycle handlers. Extend only the required lifecycle/connector/power/metadata seams. Speakers bypass composite creation, private power normalization, shell upgrade/refund, custom rotation, status artwork and item snapshot machinery. Normal mining/death removes the registry association, not a second native entity or drop. Body invalidation and surface deletion clean up only the exact retained registration.

Use the native body's red/green connector and native footprint for description. Native power availability means positive electrical energy and no script-disable, freezing or deconstruction. Do not use `entity.active` as a shortcut: it also includes circuit-control disablement, whereas direct notes must work without a circuit trigger. Read the explicit supported native flags instead; do not write power buffers, active state or energy usage.

Fix the observed-versus-owned distinction where it matters, rather than claiming registry membership means the mod owns every aspect of the native entity. In Configurator target enumeration, a registered speaker remains configurable. Composite shells and implementation children retain protection. In blueprint preparation, preserve native speaker records, native parameters and their wires when selected alone or alongside transformed composite devices. Opening, settings paste and cloning must retain ordinary native handling.

Alternative rejected: append speaker to the composite definitions and add nil guards as failures appear. The underlying ownership semantics differ, and a nil guard cannot make power normalization, blueprint rewriting or native behavior disabling safe.

### 2. Connected-frontier adoption with bounded same-color relay

Use the existing synchronized lifecycle and fair maintenance phases to adopt supported speakers encountered at registered network connectors. Build/clone/revive events can seed bounded candidate work, but they must not eagerly occupy registry capacity for every unrelated unwired speaker in the world. Existing connected speakers and entities created without raised events enter through the same physical frontier. A newly adopted speaker becomes another same-color frontier vertex, so chains become usable without an all-surfaces scan.

A discovery call encountering an eligible but not-yet-adopted entity reports `E_NETWORK_PENDING` and schedules bounded idempotent adoption; it does not return a successful inventory that omits it. Identity capacity exhaustion remains explicit and leaves the native entity/wires intact. Pre-admit edge inventories, deduplicate candidates by exact entity identity and bound retained candidate work/cursors. Do not store Lua iterator functions or rebuild storage in `on_load`.

Extend fresh traversal and witness validation to native speaker connectors using the same force/surface/role/ghost rules. Physical same-color relay is explicitly confirmed; signal values, native network IDs, a shared speaker identity or its green connector never authorize a red path. Preserve unsupported wires and ordinary signal continuity.

Native relocation/rotation updates descriptive state through reconciliation without moving the entity back. Calls use the current entity and native connector, not stale composite geometry. Force/surface reassignment invalidates existing identity-generation bindings before re-admission in the new scope; this prevents an old retained Console binding from becoming valid again merely because the device later returns. Preserve spent identity counters for the tick and do not restart computer programs.

Alternative rejected: scan all generated surfaces/chunks or adopt arbitrary vanilla relay entities. The first is unnecessary and unbounded; the second changes the trust boundary beyond the requested speaker exception.

### 3. Reuse sample definitions through one positional sound backend

Add `data-final-fixes.lua` and a focused proposed generator `prototypes/speaker-audio.lua`. Capture the supported speaker's instrument/note definitions after the declared base/Space Age dependencies. Generate private namespaced `sound` prototypes for its note samples, referencing the original assets. Normalize the documented `Sound` union forms (string, single definition, variations array/structure) into valid `SoundPrototype` definitions without modifying the source speaker or its source tables.

Copy relevant sample/variation volume, speed and modifier definitions through the pinned schema. Choose `category="game-effect"` and a local `audible_distance_modifier=1` for generated note aliases, rather than copying the speaker entity's range multiplier into a property with a different legal range. Keep the source note labels and zero-based index mapping in bounded `mod-data` metadata. Generate deterministic aliases from native instrument/note indices, and validate names/counts before exposing the catalogue. Duplicate names or oversized/malformed metadata mark the affected catalogue unavailable explicitly; they never change vanilla behavior or publish a truncated instrument list.

The runtime provider resolves `playNote` to its generated sound path. Both playback methods then call `speaker.body.surface.play_sound` once with explicit `path`, current `position`, normalized `volume_modifier`, and `override_sound_type="game-effect"`. Do not loop over players or branch authoritative admission on local audio/mute state. Positional sound fan-out remains the engine's responsibility, including charting and listeners on other forces.

This architecture deliberately treats the native speaker as the powered position/authority carrier and reuses its samples, rather than borrowing its mutable circuit playback configuration. Note aliases use native assets, but have their own documented local spatial playback and host admission limits; native circuit polyphony/range settings are not promised for API audio. Ordinary circuit playback remains untouched and can coexist.

Alternatives rejected:

- Temporarily change `entity.parameters`, invoke `play_note`, then restore: the public method has no per-call volume or audience parameter, and documented behavior does not establish when settings are latched by audio playback. It risks native/global interaction and failure-path restoration for no user benefit.
- Hidden helper speaker: adds another entity, ownership, power and lifecycle problem solely to play a sample.
- Runtime asset loading or external audio output: violates the normal Factorio mod boundary and multiplayer deployment model.

The first implementation acceptance slice must exercise positional note/effect playback, varied volume and near/far/other-force listeners in actual clients. If a documented path family cannot honor local playback, stop for contract review; do not silently broadcast or weaken the locality requirement.

### 4. Prototype-stage sound catalogue with bounded pages

The missing runtime sound registry is a real stage boundary, not an invitation to invent `prototypes.sound`. During the same final-fixes pass, collect named sound prototypes and candidates for all pinned utility, ambient, entity, tile and item sound-path families. Use the documented prefix-to-field mapping rather than synthesizing a path for every arbitrary sound-bearing field. Exclude generated private note aliases from `getSounds`, deduplicate and sort deterministically. Preserve exact path strings.

Transport metadata with real `mod-data` prototypes. Use a small versioned header, a bounded instrument-name index, bounded per-instrument note records and fixed-size sound chunks with at most the API page-size candidate paths each. A header carries counts/version and explicit catalogue-unavailable diagnostics; it does not embed the full catalogue. Use the API's maximum path bytes and counts to bound each chunk before registration. A candidate-count overflow records an explicit error state rather than truncating or failing vanilla startup.

Proposed runtime helper `scripts/speaker-audio.lua` reads these trusted chunks and constructs defensive guest results under the existing Data limits. `LuaModData.data` returns the full data block, so charge the bounded block's worst-case materialization before reading it; do not load one giant table then claim slicing made it bounded. No durable copy of the installed catalogue or unbounded startup runtime cache is necessary.

For `getSounds`, locate the prefix/lower-bound region by indexed comparisons over sorted chunks, then read only admitted chunks and validate candidates using `helpers.is_valid_sound_path`. Return up to 50 valid strings, with a valid lookahead establishing whether `next` exists. Any budget failure returns an error with no page. The continuation is a plain exclusive path key, so save/load requires no cursor state. Direct `playSound` uses native validation and is not restricted to the captured index.

Catalogue ordering is intentionally documented: declared dependencies precede capture, later third-party additions may not appear, and changed configurations require restarting a complete traversal. Runtime-validation catches removed/stale paths. This version supports the installed base/Space Age matrices and the exact vanilla carrier name; it does not claim arbitrary later mutation of instrument definitions is compatible. Reject observable metadata mismatches rather than knowingly selecting the wrong note.

Alternative rejected: hardcode a short list of useful effects and call it complete discovery. That would miss the requested capability and make installed sound availability unnecessarily opaque.

### 5. One prepared effect and durable deterministic admission

Implement the exact six-method contract in `specs/speaker-peripheral/lua-api.md`. All callbacks, Console calls and colors use the same provider. Method validation distinguishes wrong shape/type, invalid values and rate refusal; there is no guest-controlled player, position, raw path loader or scheduling mechanism.

Before dispatch:

1. Prove current wrapper authority and native availability using the existing service boundary.
2. Validate exact arity, finite bounded arguments and catalogue/path metadata, and resolve one engine sound path.
3. Admit the remaining host work and the fixed boolean result delivery. Preserve `G.service` argument/result safety: introduce only a narrow host-only pre-admitted boolean-return path for these reviewed effectful methods, or equivalent accounting that reserves the final scalar snapshot before invoking them. Do not remove result validation, weaken Data bounds, bypass fatal budgets or expose a guest extension hook.
4. Check physical-speaker note/effect counts, computer combined count and world combined count for the current synchronized tick. Validate arguments before returning rate-refusal false.
5. Commit all applicable counters together immediately before one positional engine call. Return true on successful submission. If the engine call throws, retain its spent allowance, raise `E_ENGINE` and never retry automatically.

Retain a versioned plain audio-admission ledger keyed by opaque computer/speaker identity and tick. Follow existing admission semantics: advance/reset only when the real simulation tick increases, never on Apply, reconnect, exception or reload. Keep departed identity deductions until tick advancement and bound ledger keys by existing registry/active-computer admission rather than accumulating history. Per-speaker type limits and combined global/computer limits are in the API companion; existing common budgets are unchanged.

Test the exact budget edge where the outer service previously could spend after an irreversible effect, including ordinary/fatal refusal and caught errors. No error under insufficient pre-dispatch credits may produce sound; a later independent guest statement failing does not roll back an already successful call. Backend request/return counters in tests are evidence of dispatch, not audibility.

Alternative rejected: callback-local rate counters or a deferred playback queue. Callback-local counters can be bypassed through wrappers/Console/reload; a queue adds persistence, cancellation and ownership semantics the user did not request.

### 6. Keep integration proportional and coordinate pending work

Reuse provider registration and existing graph primitives. Restrict generalization to actual shared native-carrier needs; there is no guest extension registry or wholesale lifecycle rewrite. If radar native-carrier support has landed when this is applied, reuse its narrow seams rather than creating a second incompatible marker, adoption queue or metadata dispatcher. If it has not, speaker implementation remains independently complete.

The network delta is against current main. When combining with `add-radar-modems`, merge the explicit supported vertex sets and preserve its origin filtering, radar-specific scenarios and no-remote-discovery rule. Never apply either full MODIFIED block over the other without reconciliation. Preserve speaker native opening when the inspector proposal lands, and add speaker API/player documentation to the documentation reorganization rather than creating competing navigation.

The new capability companion is part of the change's `specs` artifact set. During implementation, publish/synchronize the main speaker contract and account for it in `tools/build.py`, `tools/test_build.py`, `tools/player_docs.py`, the API manifest, site navigation and executable-example inventory. Inspect current generator inputs at apply time; do not add the example to a saved-program corpus merely because it contains Lua fences.

## Risks / Trade-offs

- Native registration currently implies composite ownership → Branch before composite mutations and change Configurator protection to actual owned bodies/helpers. Cover mixed blueprints, native GUI, mining, settings paste and original wires explicitly.
- Notes use registered sample aliases, not the native circuit audio channel → Document Factorio note indexing, local game-effect attenuation and independent API admission; verify chords/volume and coexistence rather than claiming native polyphony or CC equivalence.
- Sound-path families and later mod load order are not a universal runtime registry → Capture documented candidates, validate at runtime, disclose capture scope and reject catalogue failures explicitly. Direct valid paths remain usable.
- Generated catalogue materialization can consume opaque native work → Bound each data block before reading, precharge, use sorted chunks and test large synthetic prototype sets with existing budgets unchanged.
- A legitimate effect can outlive its controlling program → No stop/queue promise; limit admission and document that long samples already submitted are not cancelled by detach or Stop.
- Shared admission can be monopolized in synchronized order → Keep return-false semantics explicit, bound total work/audio and test contention. Do not promise round-robin audio fairness or expose a hidden priority system.
- Runtime booleans are not audible acknowledgements → Keep client state out of authoritative counters and separate signal/capture evidence from headless success.
- Full clients may lack a configured audio output in automation → Treat that as an audio-acceptance blocker. Use an isolated test audio sink/capture or explicit human listening evidence; do not modify the user's desktop audio or substitute silent recordings.

## Migration Plan

1. Add versioned native-speaker/admission state through existing synchronized initialization/configuration stages. Preserve existing schema data, identity sequence, running sources, queues and unrelated admission deductions. Unsupported new state is inert with a diagnostic, not reset-and-play.
2. Build catalogue metadata and sample aliases from the pinned installed prototypes without changing the vanilla speaker. No save entity conversion or new recipe unlock is required.
3. Begin bounded connected-frontier adoption. Preserve pre-existing speaker settings, bodies, native blueprints and wires. No `on_load` mutation, world scan or initial sound is permitted.
4. Compare released-save upgrade with ordinary cold reload as separate gates. Verify existing programs/devices, speaker native settings and same-tick counter behavior on both base and Space Age.
5. Retain a pre-upgrade save for rollback. Removing this feature must not require restoring replaced speaker entities because none are replaced. An older mod cannot be assumed to understand newer registry records; restoring the prior save/mod set is the supported rollback, not an untested live downgrade.

## Acceptance Strategy

- Contract/data: exact method inventory, arity/defaults, zero-based native note order, complete defensive inventories, path/prefix/cursor validation, chunk/count/byte bounds, duplicate/invalid metadata and native sound-path validation. Execute canonical declaration-syntax examples through the actual compiler.
- Native base/Space Age: new/pre-existing/missed-event speakers, same-color speaker chains, color/force/surface/role isolation, unpowered relay, false circuit condition with direct playback, script-disable/freeze/deconstruction, native settings/GUI/Configurator preservation, mixed blueprints and cloning/mining/replacement.
- Effects/admission: both backends use explicit position and game-effect mixer; zero-volume admission, same-tick shared per-speaker/computer/world caps, budget-edge refusal before dispatch and native-error accounting. Compare exact request counts and returned booleans; do not infer client rendering.
- Persistence: released-save installation, cold reload, same-tick deductions, delayed metadata/adoption progress, detach/force/surface/replacement revocation, late-join no replay and no saved playback queue.
- Packaging: add proposed `tests/speaker_engine.lua` and `tests/speaker_client_engine.lua` to both explicit production-context fixture allowlists where appropriate. Use fresh scratch directories, exact built ZIPs and existing `tools/smoke.py --mode both --production-context --cold` conventions; preserve full failure logs. Add a focused data-stage fixture rather than mocks alone.
- Real audio/UI: use the matching full clients and an isolated audio route. Capture note/effect samples at known schedule/positions, test distinct volumes and simultaneous notes, and inspect actual audio (plus native GUI screenshots). Test native global settings do not broaden API playback. Ordinary monitor Xvfb/MP4 harnesses are not sufficient because they do not establish audible output.
- Connected multiplayer: actual peers must exercise near/far listeners, a listener on another force, other-surface exclusion, consistent admission, disconnect and late joining. One engine's logical state and separate cold processes are not substitutes. Keep local audio-device differences out of deterministic pass/fail game state.
- Supported envelope: verify the initial published caps under concurrent existing controller/monitor workloads, with production work limits unchanged. Acceptance must either meet the documented contract or return for a deliberate revision; no silent budget inflation, dropped cases or partial catalogue success.

Record all native/client results with archive hash, engine/mod matrix, fixture, process phase, completion markers, full logs and clean exit status. Keep audio, screenshots and saves outside git under the repository's documented durable evidence location. Planning validation is not implementation acceptance.
