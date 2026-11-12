# Device artwork

Version **0.1.24 ALPHA** gives the devices a new art family. Each device copies the look of a
peripheral from CC:Tweaked or one of its addons. The blocks have worn, lightly rusted paint in
the style of the vanilla combinators. There is no theme selector or extra gameplay dependency.

## Recognize the family

| Device | Look | North-facing footprint |
| --- | --- | --- |
| Computer | CC:Tweaked Computer: black screen with CraftOS text, disk slot, green power light | 1×1 |
| KV database | CC:Tweaked Disk Drive: floppy disk in the slot, disks stacked on top | 1×1 |
| Monitor | Flat bracketed glass with bezel contacts (art not changed) | 1×1 |
| Logic handler | Three CC:Tweaked Redstone Relays with an `A > B` display | 3×1 |
| Configurator | Advanced Peripherals Inventory Manager joined to a crate | 2×1 |
| Recipe Searcher | Advanced Peripherals Geo Scanner with a radar dish | 1×1 |
| Factoriopedia Interface | CC:Tweaked Printer with printed pages | 1×1 |
| Production Statistics | Advanced Peripherals Energy Detector with a gauge and a chart | 1×1 |
| Dashboard | Tom's Peripherals keyboard and screen console | 1×1 |

The **Native circuit computers** research shows the computer. The **Recipe Searcher** research
shows the geo scanner. Item icons show the front of each device. Research prerequisites, costs
and unlocks do not change. See [research and crafting](getting-started.md#research-and-craft).

## Wiring and visible state

Each port has an antenna. The antenna has a red ring, a green ring and a band in the port color:
blue Network, orange Input, green Output and violet Factory targets. Wires attach to the rings
in every cardinal direction.

- A device with one port has its antenna on the left side.
- The logic handler has Input on the far left, Network on the center mast and Output on the far right.
- The configurator has Network on the left and Factory targets on the right.
- The monitor contacts stay on its bezel.

Existing wires stay connected after the update. Only the drawn wire end moves to the ring.
Selection boxes, collision boxes and ports do not move. The port colors do not restrict your
wire color. [Same-color discovery rules](api/peripheral.md) still apply. Rotate or mine the main
body, not an auxiliary socket.

The stopped, active, physically unavailable and fault marks stay compact. They are on a light on
the front of each device. They do not replace Factorio's native deconstruction X. Monitor glass
keeps the same active interior, alpha boundary and display model. See
[monitor behavior](api/monitor.md) and [moving/preserving data](lifecycle.md).

## Original sources and evidence limits

The models and materials are original project-MIT work, made in Blender. They copy the look of
the CC peripherals; they contain no CC:Tweaked or addon textures or models. The Blender script
and its renders are in the source repository under `art/`. The asset generator makes the game
sprites from the renders without Blender. Historical Greg Flavored inputs and complete MIT
notices remain in the package, but this family does not sample them. The character atlas is
independently authored, not an imported CC:Tweaked font.

Software-rendered client captures in base and Space Age verify the appearance and the wire ends
in all cardinal directions. They do not verify hardware FPS or multiplayer behavior.
