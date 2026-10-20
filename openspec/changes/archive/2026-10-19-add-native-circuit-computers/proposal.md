# Proposal

## Why

Factorio needs small, programmable factory controllers with a documented Lua API and physical peripheral boundaries, without emulating a full computer operating system. Computer Core supplies the callback-oriented inspiration, but its Factorio 0.16 implementation and dumped-function persistence cannot be transplanted into Factorio 2.0.77.

## What Changes

- Introduce a one-tier, electrically powered computer with one editable Lua source document, native named event handlers, explicit persistent state, timers, diagnostics and enforced resource limits. No guest filesystem, shell, interpreter or suspended Lua stacks.
- Use red or green circuit wires as physical discovery edges between this mod's network ports. Each path must retain one color; vanilla entities cannot relay peripheral discovery. Network ports do not encode, emit or expose circuit signals.
- Add flat, merging color monitors with CC:Tweaked-shaped terminal methods and touch/resize events; a Redis-inspired string/hash KV peripheral with simulation-time whole-key expiry; a rotatable 3×1 input/network/output logic handler; and a 2×1 network/target configurator.
- Expose full Factorio 2.0.77 circuit-control configuration through the configurator, including device enumeration, coordinates, type, capabilities, current configuration and validated updates. Its target-side native circuit networks are distinct from computer discovery networks.
- Support deterministic shared peripheral access and last-successful-write semantics. Clear logic outputs when their last writer loses authority, without erasing newer writers' work.
- Preserve running state through saves; preserve source/state and KV data when mined; exclude runtime/KV contents from blueprints and clones. New/replaced computers start stopped.
- Adapt the requested Greg Flavored resource-pack artwork with pinned provenance, notices, directional sprites and client verification.
- Specify every guest-facing signature, data type, event, error and lifecycle rule in companion Lua API documents and integrated examples.

This is a new mod, not a legacy-save migration or an old-script compatibility layer. No wireless messaging, direct computer messaging, audio, portable computers, third-party extension API or general Factorio-object access is included. Computers communicate through logic-handler circuit signals when desired.

## Capabilities

### New Capabilities

- `computer-runtime`: bounded native callback execution, identity, persistent state, timers, errors and deterministic scheduling.
- `program-editor`: single-document in-game authoring, validation, activation, diagnostics and conflict-safe editing.
- `peripheral-network`: color-preserving discovery, typed access, authority revalidation and shared access.
- `monitor-display`: rectangular tiled displays, CC-style terminal API, touch and resize behavior.
- `kv-database`: per-device Redis-inspired strings, hashes and whole-key expiry.
- `logic-handler`: separate input/network/output roles, signal inspection, change subscriptions and fail-safe output ownership.
- `device-configurator`: native target-network enumeration and typed configuration of the complete pinned circuit-control surface.
- `device-lifecycle`: physical entities, electricity, artwork, progression, persistence, mining and blueprint/clone behavior.

### Modified Capabilities

None. The repository has no existing capability specifications or implementation.

## Impact

Target: Factorio 2.0.77, usable with base alone and with Space Age enabled. Quality-aware identities are required without making the expansion a dependency. Implementation will need data/control-stage Lua, native GUI and rendering integration, a reviewed source parser/instrumentation path, deterministic state storage, packaged assets and isolated engine/client tests. The planning package records reference revisions and separates verified source/API facts from implementation hypotheses and release-blocking feasibility gates. This change creates planning artifacts only; no production code or assets are implemented here.
