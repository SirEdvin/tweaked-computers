# Industrial device artwork and independent glyphs (RD2)

Original editable artwork is implemented. Native-client visual review remains
user-owned and unperformed. Contact sheets are asset composites, not screenshots.

## Five functional silhouettes

- Computer: low sloped operator console, inset dark screen, keyboard/control
  strip and cooling grille. The screen is not a tall pale cube face.
- KV database: ribbed storage cabinet, stacked cartridges and folded-metal
  handles on the top/front, with an activity rail. No screen or keyboard.
- Monitor: thin flat glass panel with a metal bezel and edge contacts. Its
  original world/touch/cell geometry is unchanged.
- Logic handler: one continuous three-bay signal instrument, common case rails,
  Input chevron, central Network/processing bay and double-chevron Output.
- Configurator: one two-bay service controller, a physical dial and a separate
  Factory targets terminal bank/crosshair.

All use graphite, fine-grained steel, brass contacts and restrained activity
lights. Geometry rotates before projection; lighting and cast shadows use one
world-space direction. Their original 1×1, 1×1, 1×1, 3×1 and 2×1 footprints,
recipe costs, wire roles, service behavior and Lua API v1 are unchanged.

## Editable sources and provenance

`industrial.py` is the editable authored geometry/material source. Its small
named constructors use tile-unit coordinates and heights, with polygons, folded
metal, fasteners, grilles, keys, cartridge handles, dial and role pictograms.
Change these constructors rather than editing generated PNGs. `generate.py`
exports runtime images and metadata; it does not sample any upstream texture,
model, screenshot, font or promotional render for the new family.

`socket-layout.json` is an exact-engine export of
`scripts/device-definitions.lua`'s `offset`, `contact`, directional transform and
role colors. `export_layout.py` runs `layout-data.lua` in isolated Factorio 2.0.77
and retains 17 significant digits. This matters: rounding `-0.5 - 0.07` through
Lua's default tostring loses exact metadata equality. The exporter does not
contain another socket layout. Regeneration rejects a stale definition hash;
`tests/art_data.lua` compares every exported coordinate/color against the actual
Lua functions and installed native prototypes.

Every new PNG is original project MIT artwork. `manifest.json` format 2 records
source hashes, per-output dependencies, PNG/decoded-RGBA/alpha hashes, dimensions,
pivots, transforms, palette, encoder/tool versions and required notices. The
historical approved Greg Flavored import remains unchanged in `upstream/`, pinned
to `BirbIrl/ComputerCraft-Greg-Flavored` revision
`ac6cafc3993c902e2ca95d85b501d3c7e172570c`. Its 23 models, seven textures and two
animation metadata files remain hash-verified for source continuity, but none is
sampled by RD2. Retain its original `Greg-Flavored-MIT.txt` and credits README;
retain `Tweaked-Computers-MIT.txt` for original work. No permission/provenance gate
was reopened and no CC artwork/font is imported.

The downloadable gameplay mod excludes Python tools as required by the Mod
Portal. Editable Python sources, requirements and full history are delivered in
the source repository, not executed by Factorio. PNGs, Lua metadata, geometry
export, manifest and notices ship in the gameplay ZIP. A manifest input can thus
refer to a source-repository file intentionally absent from that ZIP.

## Immutable physical integration contract

`require('assets.sprites')` returns immutable descriptions; consumers copy them.
All image paths start `__tweaked-computers__/assets/`.

| Device | Local footprint | Frame / pivot (high-resolution pixels) |
| --- | --- | --- |
| `computer`, `kv`, `monitor` | 1×1 | 160×160 / (80,80) |
| `logic` | 3×1 | 320×320 / (160,160) |
| `configurator` | 2×1 | 320×320 / (160,160) |

Each `art.devices[kind][direction]` has `body`, `shadow`, `states` and the exported
`roles` metadata. Cardinal names are `north`, `east`, `south`, `west`; choose the
matching view instead of rotating the already projected image. North/south wide
axes become tall east/west. All body/shadow/status sprites keep scale 0.5 and
shift `{0,0}`. World projection is `(64*x - 48*height, 64*z - 128*height)` in tile
units. Native studs are painted at their actual ground coordinates, without
adding the elevated-body projection. They mount on the instrument's near face.

Filenames: `sprites/{kind}-{direction}-{layer}.png`.

| Layer | Meaning |
| --- | --- |
| body | Complete immutable original device shell and controls |
| shadow | Separate black cast ground shadow, alpha 85, `draw_as_shadow=true` |
| off | Small grey stopped dash |
| unpowered | Amber slash; monitor uses two separated bezel dots |
| powered | Green activity beacon |
| fault | Tiny red fault cross; monitor uses three separated bezel dots |
| blinking | Four frames, alternating amber/steel beacon, no whole-body flashing |

Status is deliberately compact (one to nine opaque high-resolution pixels per
frame). A fault beacon is not a native deconstruction marker. The existing bounded
`scripts/device-art.lua` selects states; it and the scheduler are unchanged. Only
a powered running computer uses blinking; powered stopped computers use off;
other powered peripherals use powered. Blinking metadata is an Animation;
`prototypes/devices.lua` slices its four frames into named SpritePrototypes.

Icons are `icons/{kind}.png`, tightly fitted 64×64 body views with transparent
padding, not borrowed item screenshots. The same shapes appear in inventory and
world sprites. Role symbols supplement position/color: Network diamond, Input
chevron, Output double chevron, Factory targets crosshair. Wire red/green is
independent of the role-marker palette; either wire color is allowed per role.

## Monitor and glyph contract (unchanged)

The monitor is a ground-centered 64×64 logical-unit square with a 60×60 interior
and exactly two units of bezel per edge. Raster bounds are half-open:
`[-32,32)` for the panel, `[-30,30)` for the glass. Socket pixels at native
±0.48 tile and all status pixels stay on that bezel. No raised lip, upright
panel, new touch offset or cell pitch is introduced. Runtime grouping may cover
internal seams; display-layer/removal-feedback work belongs to RD4.

`glyphs.txt` is the independently authored 5×7 ASCII stroke source. The unchanged
96×144 atlas has 16×16 cells of 6×9 pixels. White opaque foreground is tintable;
background is transparent. ASCII bytes 32..126 have individual glyphs. Mosaic
128..159 uses five row-major 3×3 bits with the bottom-right subcell blank. Other
bytes use the outlined replacement box. Bytes 32 and 128 are blank. No rich text
or external font is interpreted.

`art.glyphs[byte]` (0..255) retains its `x=(byte%16)*6`,
`y=floor(byte/16)*9`, width 6, height 9 and scale 1. Default gameplay zoom is 32
screen pixels/tile while the API uses 64 logical units; existing runtime glyph
scale 0.5 and cell-centered world transforms are unchanged. Do not double-apply
that scale. Native world readability/touch is still a client check, not a claim
made by glyph-mask tests.

## Reproduce and check

Use Python 3 and the Pillow version in `requirements.txt` (verified with 12.3.0).
The custom PNG encoder remains RGBA8, filter 0, zlib level 9 without ancillary
chunks. No network or system font is used for normal regeneration/contact sheets.

    python3 -m pip install -r assets/requirements.txt
    # Only when production socket definitions change; fresh external directory:
    python3 assets/export_layout.py --factorio /path/to/factorio/bin/x64/factorio \
      --output /outside/git/fresh-layout-export
    python3 assets/generate.py
    python3 assets/check.py --output /outside/git/fresh-art-check
    python3 assets/contact_sheet.py --output /outside/git/fresh-contact-sheets
    python3 tools/build.py --output /outside/git/rd2-artifact
    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive /outside/git/rd2-artifact/tweaked-computers_0.1.1.zip \
      --output /outside/git/fresh-art-engine --fixture tests.art_engine \
      --data-fixture tests.art_data

`check.py` verifies all 146 PNGs, every source/output/decoded hash, all 64 contact
pixels, five distinct north-view alpha silhouettes, fixed monitor geometry,
compact status masks, all 256 glyph slots, exact offline regeneration and an
isolated source/asset/notice ZIP inventory. `tools/test_build.py` separately checks
the actual gameplay ZIP bytes and executable exclusion. Data tests compare all
native contacts and 160 installed status frames; runtime tests draw/destroy all
461 sprites and exercise status selection/cleanup on 20 actual native shells.

The five contact sheets cover all directions, ordinary 32 pixels/tile, enlarged
128 pixels/tile, wired contact overlays/auxiliary selection bounds, all 160 status
samples and icons at 32/64/128 pixels. Adjacent vanilla scale context uses the
pinned arithmetic combinator's 1×2 footprint and 144×124, scale-0.5 frame bounds;
it is explicitly an outline, not fake vanilla rendering. The headless engine has
no artwork PNGs. Optional `--vanilla-illustration /path/to/image.png` adds an
external review illustration, explicitly not scale-calibrated. Its source/hash
and Wube artwork notice are recorded in the sheet index. Do not ship it as MIT
mod artwork.

See [RD2 verification and native checklist](../docs/rd2-verification.md). Headless
success does not prove GPU loading, visual wire alignment, ordinary-zoom quality,
hover or native monitor X visibility. Do not publish this development-version ZIP
as a replacement for alpha 0.1.1; the release milestone owns versioning/publication.
