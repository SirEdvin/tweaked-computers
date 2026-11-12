# 0.1.24 ALPHA — CC peripheral device artwork

This patch gives the devices new art. Each device copies the look of a peripheral
from CC:Tweaked or one of its addons, with worn and lightly rusted paint in the
style of the vanilla combinators. It changes no API, limit, setting, recipe,
research or save format.

## What changed

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

- The monitor art does not change.
- Each port has an antenna with a red ring, a green ring and a band in the port
  color. Wires attach to the rings. A device with one port has its antenna on the
  left side. The logic handler has Input on the far left, Network on the center
  mast and Output on the far right. The configurator has Network on the left and
  Factory targets on the right.
- The status marks keep their shapes and colors. They are on a light on the
  front of each device.
- Item icons and the two research icons show the front of the new devices.
- The models are original project-MIT work, made in Blender. They contain no
  CC:Tweaked or addon textures or models. See the [artwork guide](player/artwork.md).

Footprints, selection boxes, collision boxes and ports do not change.

## Install and upgrade

Use `tweaked-computers_0.1.24.zip`, not GitHub's automatic source archive. Keep the
ZIP unextracted. Move conflicting older archives or extracted copies aside.
Factorio **2.1** is necessary. Base alone and optional Space Age are supported.
The tested engine is **2.1.23**, not each accepted 2.1 patch or mod combination.

Saves from 0.1.23 need no migration. Existing wires stay connected; only the drawn
wire end moves to the antenna ring. For a save from 0.1.20 or older, read
[runtime upgrade and rollback](player/lifecycle.md#upgrading-to-trusted-native-lua)
first.

Back up the complete save and the matching mod set before you upgrade. To roll
back, restore both. Do not downgrade an upgraded save in place.

## Verification and limits

All engine checks used **2.1.23**, in base and Space Age. The final ZIP passed the
Python tooling tests, the static artwork check with byte-exact regeneration, the
packaged 52-fixture smoke matrix with its cold and production-context phases, the
monitor animations, the combined envelope campaign, and an upgrade of a populated
factory save from the published 0.1.23 ZIP. Software-rendered full-client captures
in base and Space Age show all devices in four directions with wires on every port.

The captures do not measure GPU FPS or connected multiplayer. This remains
**ALPHA**. Back up your saves.
