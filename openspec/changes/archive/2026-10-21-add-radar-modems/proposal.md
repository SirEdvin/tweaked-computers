# Proposal

## Why

Computers currently communicate with peripherals only through local physical wire graphs, leaving distant factory controllers without a programmable message transport. Turning vanilla radars into modem peripherals provides familiar channel-based communication without creating remote peripheral authority, with an optional Space Age upgrade for communication between planets and platforms.

## What Changes

- Recognize the existing vanilla `radar` as a `modem` peripheral through its own native red/green circuit connectors. Preserve its entity, recipe, scanning, native circuit transmission, power use, artwork and player-owned wires; do not replace it with a mod shell or require an adapter item.
- Add CC:Tweaked-inspired `open`, `isOpen`, `close`, `closeAll`, `transmit` and `isWireless` methods, plus the project's `getLimits`. Deliver `modem_message` through existing named handlers, not `os.pullEvent`, CraftOS, rednet or remote peripheral calls.
- Broadcast to listening, powered radars anywhere on the same surface, with no distance limit. Numeric modem channels are independent of the explicit red/green discovery color. Preserve same-force isolation, bounded plain-data payloads and deterministic event ordering.
- With Space Age enabled only, add a larger `tc-interplanetary-radar` and its research/recipe. Both endpoints must be this advanced tier to communicate across surfaces, including space platforms; either tier can communicate with the other on the same surface. The advanced radar uses approximately 1.5× vanilla visual scale with a practical whole-tile footprint.
- Research the advanced tier with automation, logistic, chemical, production, utility and space science packs, excluding military and planet-specific science packs. Keep ordinary radar modems usable with base alone.
- Explicitly exclude native radar-origin hidden wire links from peripheral discovery and path witnesses. Neither native circuit transmission nor modem traffic may reveal or authorize remote peripherals, bridge discovery colors, or traverse ordinary vanilla relay entities.
- Cover existing radars, shared channel state, cold saves, entity replacement, force/surface changes, power loss, bounded fan-out and overload diagnostics. Extend player/API documentation and packaged/native-client acceptance without changing existing computer execution semantics.

The range, expansion-only availability, advanced endpoints at both ends, platform inclusion and six research packs were confirmed with the user. API adaptation and balance details are proposed in the companion design and contracts.

## Capabilities

### New Capabilities

- `radar-modem`: Local radar attachment, shared channel state, bounded message broadcast and callback events, optional interplanetary tier and transport lifecycle semantics.

### Modified Capabilities

- `peripheral-network`: Admit supported radar connectors into the physical discovery graph while explicitly excluding radar-origin hidden links and wireless remote authority.
- `device-lifecycle`: Add non-invasive native-radar ownership, save migration and expansion-gated progression without treating vanilla entities as composite shells.
- `device-visual-identity`: Define the native radar visual exception and the scaled advanced radar, preserving the existing six-device Service Rack family.

## Impact

- Runtime integration touches `control.lua`, `scripts/lifecycle.lua`, `scripts/registry.lua`, `scripts/network.lua`, `scripts/services/peripheral.lua`, `scripts/runtime/computer.lua`, resource limits, scheduler admission and narrowly scoped new radar/modem modules. Existing code assumes constant-combinator shells and private power carriers; radars require an explicit native carrier path, not another entry in the existing prototype-generation loop.
- Data-stage integration adds an optional radar prototype/recipe/technology module and locale text. Reuse installed Factorio radar assets by native asset references; do not ship game data or add a library. The engine remains pinned to Factorio 2.0.77 and the existing optional Space Age dependency.
- API/spec companions, API inventory coverage, examples, generated player docs and engine fixtures must cover the new type/event without broadening the guest trust boundary. The full research ingredient list and geometry are reviewable contracts; numerical recipe/power/throughput tuning must be documented and measured before release.
- Existing saves and ordinary vanilla radar behavior must be preserved, including radars created before installation. Installation/registration capacity failure must disable only the modem integration, never destroy/refund or alter an existing vanilla radar.
- Coordinate with the separate `add-peripheral-inspectors` proposal: it covers the currently implemented peripheral families and is not an implementation dependency. This change preserves native radar opening and requires no new inspector UI or edits to that proposal.
- No implementation, release, publication, dependency installation or modification of existing player saves is authorized by this planning change.
