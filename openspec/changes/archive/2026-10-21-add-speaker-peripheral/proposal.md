# Proposal

## Why

Computers can configure a vanilla programmable speaker's circuit settings through a Configurator, but cannot discover it as a speaker peripheral or directly request notes and sound effects. Exposing the existing speaker enables programmable factory alarms and melodies without a replacement entity, adapter item or unsupported promise of arbitrary audio streaming.

## What Changes

- Expose the existing `programmable-speaker` entity as peripheral type `speaker` through its native red/green circuit connectors. A speaker relays physical discovery on the same wire color; it never bridges red and green or grants access through other unsupported vanilla entities.
- Add synchronous, bounded `playNote` and `playSound` methods, plus `getInstruments`, `getNotes`, paginated `getSounds` and the standard `getLimits`. Publish their exact contract in the companion `specs/speaker-peripheral/lua-api.md` artifact.
- Play requested audio locally at the speaker's position on its surface, audible to nearby players regardless of force under the engine's normal charting, distance and audio settings. Control authority remains same-force and same-surface. Do not offer global broadcasting.
- Preserve the vanilla speaker's entity, recipe, power behavior, GUI, native circuit playback/settings, wires, blueprints and mining results. Peripheral registration must not accidentally block its existing Configurator support.
- Adopt already placed connected speakers with bounded synchronized reconciliation; preserve exact identities and spent playback allowances across ordinary save/load. Revoked or unpowered paths cannot submit new audio.
- Add contract, packaged base/Space Age, cold-reload, native-client audio and connected-multiplayer acceptance, together with player-facing API documentation and runnable alarm/melody examples.
- Deliberately exclude `playAudio`, streamed files/PCM/DFPWM, a `stop` method, sound-pitch resampling, playback-completion events, new speaker items and exact CC:Tweaked compatibility. Notes use Factorio's installed instrument/note catalogue; a successful submission does not certify that a client's mixer rendered it.

## Capabilities

### New Capabilities

- `speaker-peripheral`: Native programmable-speaker integration, discoverable instruments/notes/sound paths, bounded local playback, preservation of native behavior, identity/lifecycle and audio acceptance contracts.

### Modified Capabilities

- `peripheral-network`: Permit registered vanilla speakers as same-color physical discovery vertices; preserve native circuit behavior and opening while retaining force/surface/role isolation and the prohibition on other unsupported vanilla relays.

## Impact

- Runtime: `scripts/registry.lua`, `scripts/lifecycle.lua`, `scripts/network.lua`, `scripts/services/peripheral.lua`, scheduler admission, blueprint/presentation paths and the single event owner in `control.lua`; add a focused native-speaker adapter and speaker service instead of inserting vanilla speakers into the composite-device prototype loop.
- Configuration: distinguish observing a native peripheral from owning/protecting an implementation entity in `scripts/configuration/targets.lua`; retain existing speaker validation in `scripts/configuration/adapters.lua`.
- Data/runtime catalogue boundary: Factorio 2.0.77 exposes instrument metadata and sound-path validation, but no runtime `prototypes.sound` registry. Sound discovery needs a bounded prototype-stage catalogue transported through the supported `mod-data` facility, not a fabricated runtime API.
- Public contracts/docs/tests: add the dedicated Lua API specification, update peripheral discovery documentation and method inventories, include executable examples and validation evidence, and update package/documentation fixture inventories where required.
- No new dependency, copied game audio, replacement speaker prototype, extra recipe or research. Retain the pinned base and optional Space Age 2.0.77 matrix.
- Coordination: the separate, unimplemented `add-radar-modems` proposal also changes native-carrier lifecycle and physical reachability. Reconcile the union of those requirements whichever lands first; this change neither implements radar behavior nor depends on that proposal being implemented. Preserve the unrelated inspector and documentation proposals.
