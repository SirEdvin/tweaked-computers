# Proposal

## Why

The mod eagerly registers ordinary radars and repeatedly walks them even when no computer exists: an isolated Factorio 2.1.23 diagnostic measured average scheduler time rising from 0.033 ms with no radars to 9.337 ms with 1,000 unwired radars and zero computers. Computer-independent radar maintenance must stop for existing saves as well as new placements, without discarding previously accepted modem state.

## What Changes

- Discover radar modems only from a placed computer's existing valid physical network: direct or indirect, one wire color, one force and surface, through supported network connectors only. Preserve speaker/radar relays; do not traverse hidden radio links, unsupported vanilla relays or factory-only ports.
- Stop enrolling radars solely because they were built, revived or cloned, or connected to a standalone peripheral. Remove the all-device adoption frontier as a source of radar enrollment.
- Separate remembered radar identity/channel data from recurring work. A disconnected remembered radar is dormant: no availability sampling, adoption, registry maintenance sweep, radio-candidate scan or dormant-pool polling. Reconnection to the same entity in the same scope preserves its opaque identity and channels.
- Migrate previously registered radars out of generic ticking lists before ordinary tick dispatch resumes on upgrade. Ordinary reloads retain that separation; players do not need to mine radars, reconnect cables or wait for a legacy-radar sweep to finish.
- Keep discovery independent of whether a connected computer program is running. Preserve live power/authority checks on use, exact native-entity ownership, queued-message snapshots, no replay and existing modem method signatures.
- Require structural no-scan assertions and matched idle timing measurements for fresh worlds, populated legacy saves, detach/reconnect and cold reload. No budget increase or new capacity knob is part of this change.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `radar-modem`: computer-connected enrollment, dormant identity/channel retention without recurring work, and existing-save/ordinary-load guarantees. Supply a change-local `lua-api.md` companion documenting the unchanged signatures and revised attachment/persistence behavior.
- `peripheral-network`: computer-rooted native-carrier discovery that preserves transitive same-color paths without allowing disconnected components to enroll or sustain radar work.

## Impact

- Production implementation will concern `control.lua`, `scripts/registry.lua`, `scripts/radar.lua`, `scripts/lifecycle.lua`, `scripts/network.lua`, `scripts/services/peripheral.lua` and `scripts/services/modem.lua`. Audit consumers of `root.order`, especially generic scheduler, output, monitor, art and KV passes, rather than merely adding an early return inside radar reconciliation.
- Native destruction cleanup and force/surface events must still reach remembered radar records outside recurring iteration. Preserve the existing registry capacity policy; dormant state must not create an unbounded retention loophole.
- Update radar, modem, network, speaker-relay and upgrade fixtures plus relevant package/harness checks. Add an immutable 0.1.15-to-candidate upgrade case; the current radar upgrade harness primarily covers installing integration into 0.1.10 and is not that regression.
- Update the modem API reference, player guide and in-game reference as needed. No new dependencies, settings, peripheral methods, wire semantics or changes to native radar scanning/circuit transmission.
- Retained records still occupy memory and save bytes; the guarantee is no recurring mod work proportional to disconnected-radar count, not zero serialization cost or removal of Factorio's own radar simulation.
- This change contains planning artifacts only. Benchmark evidence describes the unchanged baseline, not a verified improvement.
