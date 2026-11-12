## Why

The Service Rack device art looks too clean beside vanilla combinators. The user reviewed several Blender concepts in the 2.1.23 client and selected a new family: each device copies the look of a CC:Tweaked or addon peripheral, with worn and lightly rusted paint in the vanilla combinator style. Wires attach to modelled antennas.

Evidence of the reviewed previews: `/home/siredvin/artifacts/tweaked-computers/computer-redesign-concepts-2026-11-08/` (`family-d`, `family-d-rust`, `computer-d-final`).

## What Changes

- New body, shadow, item icon and technology icon art for eight devices. The monitor art does not change.

  | Device | Look |
  | --- | --- |
  | Computer | CC:Tweaked Computer |
  | KV database | CC:Tweaked Disk Drive |
  | Logic handler | Three CC:Tweaked Redstone Relays |
  | Configurator | Advanced Peripherals Inventory Manager and a crate |
  | Recipe Searcher | Advanced Peripherals Geo Scanner |
  | Factoriopedia Interface | CC:Tweaked Printer |
  | Production Statistics | Advanced Peripherals Energy Detector |
  | Dashboard | Tom's Peripherals keyboard and screen |

- Each port has an antenna with a red ring, a green ring and a band in the role color. The native wire points and wire shadow points move to these rings. Single-port devices have the antenna on the left side. The logic handler has Input on the far left, Network on a center mast and Output on the far right. The configurator has Network on the left and Factory targets on the right.
- The status marks keep their shapes, colors and frames. They move onto a light on the front of each new model.
- Item icons and the two technology icons show the front (north) view of the new models.
- The editable source is the Blender script `art/cc_family.py`. Its renders are committed in `art/renders/` and are not packaged. `assets/generate.py` makes the game sprites from these renders without Blender.

Not changed: footprints, collision and selection boxes, role sockets and their offsets, the monitor art and its contacts, recipes, research, power, gameplay, runtime behavior and the save format. Existing wires stay connected; only the drawn wire end moves.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `device-visual-identity`: the selected family changes from Service Rack to the CC peripheral family. The monitor keeps its Service Rack art.
- `factoriopedia-interface`: the interface uses the printer body of the new family.
- `device-lifecycle`: the artwork provenance requirement names the new family and its committed renders.

## Impact

- Art source: `art/cc_family.py`, `art/model-points.json`, `art/renders/*.png` (not packaged).
- Generator and checks: `assets/generate.py`, `assets/industrial.py` (status anchor), `assets/check.py`, regenerated `assets/sprites/`, `assets/icons/`, `assets/sprites.lua`, `assets/manifest.json`, `assets/socket-layout.json`.
- Production: `scripts/device-definitions.lua` (antenna contact points).
- Tests: `tools/test_build.py` (selected family name).
- Docs: `assets/README.md`, `docs/player/artwork.md`.

## API Impact

Status: none
Reason: No guest-visible function, field, argument, result, error, work charge or limit changes. Only prototype art and native wire drawing points change.
Compatibility: Existing saves, wires and blueprints load without migration; wires draw to the new antenna rings.
Reviewed-source: 822bc00664be744685cd418818c9c1c261aa5d004932bdd5ce4e9b2ef3b2cac1
