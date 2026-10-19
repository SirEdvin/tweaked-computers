# Service Rack device artwork and independent glyphs

Service Rack (AR2 candidate B) is the user-selected six-device family. All 176
pre-existing generated PNGs match the selected preview byte-for-byte, including
all status masks, glyphs and flat-monitor shadows. Two new 256×256 technology
icons depict its computer and Recipe Searcher. Research costs, prerequisites,
unlocks, recipes and runtime behavior are unchanged.

## Identify the six devices

- Computer: folded-steel L desk, recessed display, separate keyboard apron and
  asymmetric cooling hump.
- KV database: three offset cartridges with pale handles and a cooling spine.
- Monitor: flat dark glass with green inset rails and pale corner brackets.
- Logic handler: long rail instrument, central processing hood and four exposed
  ceramic terminal banks; separate Input, Network and Output sockets.
- Configurator: open service caliper/yoke with a round reference dial and narrow
  tongue; separate Network and Factory targets sockets.
- Recipe Searcher: low paper-bed scanner sled with broad overhead scan carriage.

The green folded steel, dark iron, ceramic and copper details share fixed
world-space lighting, deterministic surface grain and geometry-cast shadows.
Shapes rotate before projection. Footprints remain 1×1, 1×1, 1×1, 3×1, 2×1 and
1×1 respectively. Selection/collision, power, sockets, touch and every API stay
unchanged. There is no runtime theme selector.

## Editable sources, selection and notices

Edit `service_rack.py`, not generated PNGs. It contains only selected B meshes
and the common depth rasterizer, extracted from AR2 source checkpoint
`9cbd4ae73c1c62763724735ea93428a3e2d5f5f5`. It reuses `industrial.py`'s contacts
and status masks and `foundry.py`'s unchanged monitor foundation/shadow. Earlier
body constructors remain historical helpers, not active alternatives.

Selected preview SHA256:
`75f43f0ddadd4ec6c0a880a2169c2bca5e225341b311859299cc5a7411182cb3`.
The technology icons were not in that preview: both are new transparent 256px
south-body derivatives, tightly fitted with one-eighth padding. Item icons keep
the exact selected 64px bytes. `sprites.lua` exports `art.technologies` for the
two actual technology prototypes; no research ownership or effects are changed.

All new geometry and pixels are original project MIT work. Reference study
techniques (not pixels or meshes) included Nixie's recessed frame/feet/vent
hierarchy. Exact inspected upstream versions, licenses, notices and hashes are
retained externally in
`/home/siredvin/artifacts/tweaked-computers/ar2-three-families-2026-10-19/reference-provenance.json`
and the sibling `ar1-reference-research-2026-10-19` bundle. Free download is not
permission to reuse art; restricted and unclear reference art was not copied.
The production generator needs none of those downloaded references.

Historical approved Greg Flavored inputs remain byte-identical under
`upstream/`: repository `BirbIrl/ComputerCraft-Greg-Flavored`, revision
`ac6cafc3993c902e2ca95d85b501d3c7e172570c`, 23 models, seven textures and two
animation metadata files. They are hash-verified for source continuity but not
sampled. Retain `notices/Greg-Flavored-MIT.txt`, its credits README and
`notices/Tweaked-Computers-MIT.txt`. No external font or CC artwork is imported.

`manifest.json` records source hashes, exact source dependencies per output,
PNG/RGBA/alpha hashes, dimensions, pivots, projection, materials, encoder and
Pillow/NumPy versions, required notices and selected-preview identity. It is
regenerated from actual production sources, not copied from the preview's old
manifest. Python tooling remains source-repository-only; the Portal gameplay ZIP
contains images, Lua metadata, manifests, socket layout and notices, not Python
executables. Source dependencies in the manifest may intentionally refer to
repository files excluded from the gameplay ZIP.

## Physical integration contract

`socket-layout.json` is the exact-engine export of production
`scripts/device-definitions.lua` coordinates, transforms and role colors.
`export_layout.py` uses Factorio 2.0.77 and retains 17 significant digits.
Regeneration refuses a changed definition hash; `tests/art_data.lua` compares
all coordinates with the real native prototypes.

`require('assets.sprites')` returns immutable descriptions; consumers copy them.
All image paths start `__tweaked-computers__/assets/`.

| Device | Local footprint | Frame / ground pivot (high-resolution pixels) |
| --- | --- | --- |
| computer, kv, monitor, recipe_searcher | 1×1 | 160×160 / (80,80) |
| logic | 3×1 | 320×320 / (160,160) |
| configurator | 2×1 | 320×320 / (160,160) |

Each device/direction exports body, shadow, states and roles. Choose north,
east, south or west rather than rotating projected pixels. All sprites keep
scale 0.5 and shift `{0,0}`. Projection is `(64*x - 48*h, 64*y - 128*h)` in tile
units. Contact overlays use their actual ground coordinates, not the elevated
body projection. Network diamond, Input chevron, Output double chevron and
Factory targets crosshair supplement socket position and color; either wire
color is permitted per role.

Status sheets remain byte-identical: grey stopped dash, amber unpowered slash,
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

Use Python 3 with the exact offline dependencies in `requirements.txt`:
Pillow 12.1.1 and NumPy 2.4.2, matching the selected preview. Mesh sprites use
3× barycentric depth rasterization and Lanczos downsampling. Selected bodies,
icons and mesh shadows use Pillow PNG compression level 9; unchanged status,
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
verify 178 outputs, all source/output/decoded hashes, transparent margins,
72 exact socket pixels, six distinct silhouettes, full monitor alpha/interior,
192 compact status frames, all 256 glyphs, both research images, byte-exact
regeneration and package notices/inventory. Contact sheets are generated asset
composites with explicitly labelled vanilla footprint outlines, not native
screenshots. Actual graphical acceptance and software-rendering limitations are
recorded in [AR3 integration](../docs/artwork-service-rack.md). Historical
[RD2](../docs/rd2-verification.md) and AR2 evidence remains immutable.

This artwork handoff does not publish, tag, bump a version or replace any
immutable release; final integration/publication is a separate milestone.
