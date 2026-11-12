# CC peripheral device artwork and independent glyphs

The selected family (candidate D, light rust) gives eight devices the look of a
CC:Tweaked or addon peripheral, with worn, lightly rusted paint in the vanilla
combinator style. The monitor keeps its Service Rack art byte for byte. Research
costs, prerequisites, unlocks, recipes and runtime behavior do not change.

| Device | Look | Footprint |
| --- | --- | --- |
| computer | CC:Tweaked Computer | 1×1 |
| kv | CC:Tweaked Disk Drive | 1×1 |
| monitor | Service Rack flat bracketed glass (unchanged) | 1×1 |
| logic | three CC:Tweaked Redstone Relays | 3×1 |
| configurator | Advanced Peripherals Inventory Manager and a crate | 2×1 |
| recipe_searcher | Advanced Peripherals Geo Scanner | 1×1 |
| factoriopedia_interface | CC:Tweaked Printer | 1×1 |
| production_statistics | Advanced Peripherals Energy Detector | 1×1 |
| dashboard | Tom's Peripherals keyboard and screen | 1×1 |

Each port of the eight devices is a modelled antenna: ceramic insulators, a
role-color band, a red ring and a green ring. The native wire points are the
ring centres. The inventory has 265 PNGs, 96 contacts and nine distinct
silhouettes.

## Editable sources, selection and notices

Edit `../art/cc_family.py` (Blender 4.0.2, Cycles), not generated PNGs:

    blender -b -P art/cc_family.py -- art/renders [kind ...]

It writes `art/renders/<kind>-<direction>-{body,shadow}.png` at 128 px per tile
and `art/model-points.json` (antenna rings and status lights, north frame, x
east, y south, z up, in tiles). Commit both. The renders are the reproducible
input, because Cycles output can change between Blender versions. `art/` is
not packaged.

`generate.py` downscales the renders with Pillow Lanczos to 64 px per tile. It
makes the shadow layer from the shadow-catcher alpha: alpha below 12 becomes 0,
then alpha × 0.72 in black. Item and technology icons are the north (front)
views. Status marks keep the existing patterns; their anchor is the projected
status light of the model. When the antenna points change, copy them to
`M.antennas` in `scripts/device-definitions.lua` and run `export_layout.py`;
`generate.py` refuses an exported layout that differs from the model points.

The monitor still comes from `service_rack.py` and `foundry.py` (selected B
preview, AR2 checkpoint `9cbd4ae73c1c62763724735ea93428a3e2d5f5f5`).
`industrial.py` keeps the status patterns and the monitor contacts.

All new geometry and pixels are original project MIT work. The models copy the
look of the CC peripherals; no CC:Tweaked or addon texture, model or font is
imported.

Historical approved Greg Flavored inputs remain byte-identical under
`upstream/`: repository `BirbIrl/ComputerCraft-Greg-Flavored`, revision
`ac6cafc3993c902e2ca95d85b501d3c7e172570c`, 23 models, seven textures and two
animation metadata files. They are hash-verified for source continuity but not
sampled. Retain `notices/Greg-Flavored-MIT.txt`, its credits README and
`notices/Tweaked-Computers-MIT.txt`. No external font or CC artwork is imported.

`manifest.json` records source hashes, exact source dependencies per output,
PNG/RGBA/alpha hashes, dimensions, pivots, projection, materials, encoder and
Pillow/NumPy versions, required notices and the selected family. It is
regenerated from actual production sources and the committed renders. Python
tooling remains source-repository-only; the Portal gameplay ZIP contains images, Lua metadata, manifests, socket layout and notices, not Python
executables. Source dependencies in the manifest may intentionally refer to
repository files excluded from the gameplay ZIP.

## Physical integration contract

`socket-layout.json` is the exact-engine export of production
`scripts/device-definitions.lua` coordinates, transforms and role colors.
`export_layout.py` uses Factorio 2.1.23 and retains 17 significant digits.
Regeneration refuses a changed definition hash; `tests/art_data.lua` compares
all coordinates with the real native prototypes.

`require('assets.sprites')` returns immutable descriptions; consumers copy them.
All image paths start `__tweaked-computers__/assets/`.

| Device | Local footprint | Frame / ground pivot (high-resolution pixels) |
| --- | --- | --- |
| computer, kv, recipe_searcher, factoriopedia_interface, production_statistics, dashboard | 1×1 | 192×192 / (96,96) |
| monitor | 1×1 | 160×160 / (80,80) |
| logic | 3×1 | 320×320 / (160,160) |
| configurator | 2×1 | 320×320 / (160,160) |

Each device/direction exports body, shadow, states and roles. Choose north,
east, south or west rather than rotating projected pixels. All sprites keep
scale 0.5 and shift `{0,0}`. For the CC devices a model point `(x, y, z)` (after
the direction transform) projects to `(64*x, 64*(y - z/sqrt(2)))` pixels from the
pivot; the monitor keeps `(64*x - 48*h, 64*y - 128*h)` with ground-level
contacts. Antenna position and band color tell the roles apart; either wire
color is permitted per role.

Status marks keep their patterns: grey stopped dash, amber unpowered slash,
green powered beacon, red fault cross and four-frame amber/steel activity.
Each frame has one to nine opaque pixels, never whole-body flashing. Native
deconstruction feedback is not replaced. Only a powered running computer
blinks; other state selection remains in unchanged `scripts/device-art.lua`.

## Monitor and glyph invariants

The monitor keeps the exact full alpha mask and every active-interior RGBA
pixel. Logical/touch tile is 64×64, interior 60×60 (`[-30,30)`), inner bezel two
units and mechanical skirt four units beyond the original tile. The skirt's
exact chamfered alpha bounds remain `[-36,36)` on both axes. This visual overhang
does not enlarge collision, selection, touch or cell pitch. Native contacts at
±0.48 tile and compact status marks stay on the inner bezel. Live content
layers may cover inner decoration and merged seams; bezel changes are not a
new display-geometry feature.

`glyphs.txt` is independently authored 5×7 ASCII; unchanged atlas is 96×144 with
16×16 cells of 6×9 pixels. ASCII 32..126, five-bit mosaics 128..159 and outlined
replacement glyphs retain the original mapping. Byte 32 and 128 are blank.
White opaque masks are tinted by the runtime palette. The unchanged opaque
1×1 `glyphs/pixel.png` supports layered fill/background/cursor sprites. No
external font, screenshots or promotional renders enter generated art.

## Reproduce and verify

Use Python 3.13+ (CI uses 3.14) with the exact offline dependencies in `requirements.txt`:
Pillow 12.1.1 and NumPy 2.4.2, matching the selected preview. Mesh sprites use
3× barycentric depth rasterization and Lanczos downsampling. Normals/projection
use explicit forward `math.fma` reductions rather than
CPU-dispatched BLAS, preserving the approved bytes across runner architectures.
Selected bodies, icons and mesh shadows use Pillow PNG compression level 9; unchanged status,
glyph and monitor-shadow outputs retain RGBA8 filter-0 zlib-level-9 encoding.

    python3 -m pip install -r assets/requirements.txt
    python3 assets/generate.py
    python3 assets/check.py --output /outside/git/fresh-art-check
    python3 tools/test_build.py
    python3 tools/build.py --output /outside/git/package
    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive /outside/git/package/tweaked-computers_0.1.9.zip \
      --output /outside/git/fresh-art-engine --mode both \
      --fixture tests.art_engine --data-fixture tests.art_data

Only re-export socket layout when production definitions change. Static checks
verify 265 outputs, all source/output/decoded hashes, transparent margins,
96 contacts (monitor socket pixels, opaque antenna rings), nine distinct silhouettes, full monitor alpha/interior,
288 compact status frames, all 256 glyphs, both research images, byte-exact
regeneration and package notices/inventory. Contact sheets are generated asset
composites with explicitly labelled vanilla footprint outlines, not native
screenshots. Actual graphical acceptance and software-rendering limitations are
recorded in [AR3 integration](../docs/artwork-service-rack.md). Historical
[RD2](../docs/rd2-verification.md) and AR2 evidence remains immutable.

This artwork handoff does not publish, tag, bump a version or replace any
immutable release; final integration/publication is a separate milestone.
