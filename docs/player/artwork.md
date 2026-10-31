# Service Rack artwork

Version **0.1.10 ALPHA** adopts the selected Service Rack family for all six
programmable devices. Their inventory icons, world bodies and research icons
use the same green folded steel, dark iron, ceramic and copper details.
There is no theme selector or extra gameplay dependency.

## Recognize the family

| Device | Distinctive form | North-facing footprint |
| --- | --- | --- |
| Computer | Folded desk with inset controls and a low display | 1×1 |
| KV database | Offset cartridge stack and service handles | 1×1 |
| Monitor | Bracketed flat glass and compact bezel contacts | 1×1 |
| Logic handler | Long ceramic-terminal rail; Input / Network / Output | 3×1 |
| Configurator | Open caliper and dial; separate Factory targets socket | 2×1 |
| Recipe Searcher | Low scanner sled with a copper optical bridge | 1×1 |

**Native circuit computers** research depicts the folded desk. The separately
researched **Recipe Searcher** technology depicts the scanner. These are two
new matching 256px icons, not changes to research prerequisites, costs or unlocks.
See [research and crafting](getting-started.md#research-and-craft).

## Wiring and visible state

The redesign does not move wire contacts, selection/collision boxes, ground
pivots or monitor touch geometry. Red and green wires still attach to the same
native roles in every cardinal orientation. Device and role-marker colors do
not restrict the wire color you choose; [same-color discovery rules](api/peripheral.md)
still apply. Rotate or mine the main body, not an auxiliary socket.

Stopped, active, physically unavailable and fault cues remain compact. They do not replace
Factorio's native deconstruction X. Monitor glass keeps the same active interior,
alpha boundary and display model; marking/cancelling a device does not turn a
status symbol into a removal action. See [monitor behavior](api/monitor.md) and
[moving/preserving data](lifecycle.md).

## Original sources and evidence limits

The selected meshes/materials are original project-MIT work. All 176 existing
PNG outputs reproduce the approved Service Rack preview exactly; the two research
icons are separately traceable additions. Historical Greg Flavored inputs and
complete MIT notices remain in the package, but this family does not sample them.
The character atlas is independently authored, not an imported CC:Tweaked font.

Editable sources, pinned export dependencies, notices and per-output hashes are
in the [release asset source](https://github.com/SirEdvin/tweaked-computers/tree/alpha-0.1.10/assets).
The [technical artwork receipt](https://github.com/SirEdvin/tweaked-computers/blob/alpha-0.1.10/docs/artwork-service-rack.md)
keeps the original selection and verification boundaries separate from publication.
Native base/Space Age tours include actual research UI, all cardinal bodies,
real wire edges, selection/deconstruction and changing standalone/merged monitors.
Software-rendered captures verify finite appearance cases, not hardware FPS,
physical-display smoothness, exhaustive wire interaction or multiplayer acceptance.
