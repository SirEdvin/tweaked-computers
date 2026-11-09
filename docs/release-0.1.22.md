# 0.1.22 ALPHA — monitor graphics mode and row text

This patch adds a graphics mode to monitors. It also draws terminal rows as text
and decreases the host work of monitor and guarded calls.

## What changed

- Monitors have a mode. `m.setMode("graphics")` and `m.getMode()` set and read it.
  The default mode is `terminal`. A real change clears the screen and queues
  `monitor_resize` with reason `mode`.
- In graphics mode, `drawLine`, `drawPolygon`, `drawRectangle`, `drawCircle`,
  `drawArc`, `drawText`, `drawSprite` and `drawLight` make retained objects and
  return their IDs. `set`, `get`, `getObjects`, `destroy`, `bringToFront`,
  `moveToBack` and `clear` manage the objects. See the
  [monitor API](player/api/monitor.md).
- Graphics coordinates are content pixels, 64 for each tile. The origin is the
  top-left corner of the content area. The mod refuses an object that leaves the
  content area with `E_RANGE`.
- Graphics objects count against the existing `render_object_limit`. A monitor in
  graphics mode cannot be in a sync group. Terminal methods raise `E_UNSUPPORTED`
  in graphics mode. Graphics methods raise `E_UNSUPPORTED` in terminal mode.
- Terminal rows draw as text in a 6×9 font that the mod supplies. Each row uses one
  background object and one glyph object. Before, each cell used its own sprite.
  A 126×84 wall needs about 570 native objects. Before, it needed about 43,000.
- A changed cell or row keeps its native object. Guarded calls with only scalar
  arguments do not copy them. Graphics calls check and charge their property tables
  but do not copy them. A `set` that changes only the text or the colour of
  left-aligned text writes only that native property.

The terminal API, work charges, limits and refusal codes do not change. The
graphics methods are additions.

## Install and upgrade

Use `tweaked-computers_0.1.22.zip`, not GitHub's automatic source archive. Keep the
ZIP unextracted. Move conflicting older archives or extracted copies aside.
Factorio **2.1** is necessary. Base alone and optional Space Age are supported.
The tested engine is **2.1.23**, not each accepted 2.1 patch or mod combination.

Saves from 0.1.21 upgrade their monitor content in synchronized work. Text,
colours, palette, cursor and text scale stay. For a save from 0.1.20 or older, read
[runtime upgrade and rollback](player/lifecycle.md#upgrading-to-trusted-native-lua)
first.

Back up the complete save and the matching mod set before you upgrade. To roll
back, restore both. Do not downgrade an upgraded save in place.

## Verification and limits

All engine checks used **2.1.23**, in base and Space Age. The final ZIP passed the
Python tooling tests, the packaged 52-fixture smoke matrix with its cold and
production-context phases, the four-walls and mixed monitor animations, and an
upgrade from the published 0.1.21 ZIP.

Performance values come from headless runs. They do not include GPU time or
connected multiplayer. This remains **ALPHA**. Back up your saves.
