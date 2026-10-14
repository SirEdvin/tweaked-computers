# Device artwork and independent glyphs (TC02)

Implementation complete; native client verification deferred to the user.
This directory contains real outputs, not the promotional preview or a license
request. It does not register gameplay prototypes or implement monitor rendering.

## Permission and pinned inputs

The user explicitly confirmed that the specific selected Greg Flavored assets
are MIT, not CC:Tweaked assets, and authorized their use. This supersedes the
previous speculative permission blocker. No separate legal audit, upstream
permission letter, replacement-art approval or publication authorization is
claimed.

The requested refreshed advanced/HV family is pinned to
`BirbIrl/ComputerCraft-Greg-Flavored` revision
`ac6cafc3993c902e2ca95d85b501d3c7e172570c`.
`source-audit.json` inventories 23 models, seven actually referenced RGBA textures
and two animation metadata files. `upstream/` retains all 32 original Git blobs
without re-encoding, recoloring or changing source alpha. Every imported file
has an exact upstream path/hash. The original root MIT notice, including
`Copyright (c) 2024 BirbIrl`, is retained verbatim in
`notices/Greg-Flavored-MIT.txt`; the original credits README is also retained.
Historical CC byte-comparison evidence is not a permission determination and
no CC artwork/font or CCPL notice is imported.

Advanced computer models inherit the normal front and replace the case with
HV bindings. Advanced monitors actually use `monitor_normal_front.png`; their
unused `monitors/advanced/...` bindings are not conversion inputs. External
Minecraft parent references are not imported: selected models provide their
own element geometry. `generate.py` resolves local inheritance and texture
aliases and samples those actual faces/UV rotations.

Authored role badges, status beacons, device letters, projection/shadows,
conversion code and glyph strokes are MIT under
`notices/Tweaked-Computers-MIT.txt`. Keep both complete MIT notices and the
manifest with distributed derivatives. `manifest.json` records source/output
SHA-256, decoded RGBA/alpha hashes, each output's actual read dependencies,
applicable notices, transform, dimensions and pivots. There are no blocked
selected inputs under the user-confirmed permission basis.

## Immutable physical integration contract

Load `require("assets.sprites")` at data stage. It returns descriptions only;
consumers copy them before adding type/name or changing fields. All filenames
are prefixed `__tweaked-computers__/assets/`.

| Device key | Footprint in its local axes | Frame / pivot (pixels) |
| --- | --- | --- |
| `computer`, `kv`, `monitor` | 1×1 | 160×160 / (80,80) |
| `logic` | 3×1 | 320×320 / (160,160) |
| `configurator` | 2×1 | 320×320 / (160,160) |

Each `art.devices[key][direction]` has `body`, `shadow`, and `states` descriptions.
Directions are `north`, `east`, `south`, `west`, cardinal clockwise rotations.
A horizontal logic/configurator axis is local right, rotated with direction;
thus north/south are wide and east/west tall. Footprints, pivots and ground
coordinates are independent of transparent margins. Scale is 0.5 and shift
is `{0,0}` for every body/shadow/status frame. Do not rotate a pre-projected
body sprite again: choose its matching direction.

Filenames are `sprites/{key}-{direction}-{layer}.png`, where layer is:

- `body`: immutable textured shell, with recognizable HV casing/front;
- `shadow`: separate black ground shadow (alpha 85), `draw_as_shadow=true`;
- `off`, `unpowered`: transparent status masks; keep the body visible;
- `powered`: green beacon and original computer front glow when visible;
- `fault`: red cross beacon, without the powered front glow;
- `blinking`: four horizontal frames of original front glow plus an authored
  alternating beacon. Frame count/line length 4, animation speed 0.15.

Layer order is shadow, body, then selected status. Blinking is an Animation
rather than a Sprite; other states are single Sprites. Do not place animation
fields on SpritePrototype. `engine-data.lua` demonstrates frame slicing for
test-only SpritePrototype registration. Off/unpowered have the same inactive
visual intentionally; gameplay status/tooltips can distinguish them.

Each `art.devices[key]` has `icon` and `icon_size=64`. Concrete files are
`icons/computer.png`, `kv.png`, `monitor.png`, `logic.png`, `configurator.png`.
Icons are tightly fitted 64×64 nearest-neighbour body views with transparent
padding. They do not use Minecraft item/promotional screenshots.

Port cues do not rely on wire color: INPUT is an amber I, NETWORK a cyan
hollow diamond, OUTPUT a lime hollow square, TARGET a violet T. KV/logic/
configurator have independently etched K/L/C identity marks. Local role
centres are x=0 for single bodies; logic x=-1,0,+1 for input/network/output;
configurator x=-0.5,+0.5 for network/target. Cue ground y is 5/16 tile (monitor
31/64 on the bezel). `manifest.json` rotates these centres per direction.
Raised bodies project source height as `screen_x -= 0.75*h` and
`screen_y -= 2*h` in high-resolution pixels; ground x/z use 4 pixels/source
unit (16 source units/tile). To align connectors with raised cues, their
visual position also includes the height projection: at h=16, displacement
is (-12,-32) high-resolution pixels, or (-3/16,-1/2) tile. Cue centres are
artwork hints, not an authorization/topology contract; physical workers own
selectable native connectors and must use explicit connector offsets.

Monitor adaptation deliberately remaps the source north face to a flat
screen-facing top plane, centred on its ground position. Its world rectangle
is exactly one tile, with a 2/64-tile bezel each edge; it has no raised-screen
perspective skew. This matches the monitor API's 64 logical units/tile, with
one uniform transform for text and touch. Beacons stay on the bezel. Group
presentation must paint backgrounds/glyphs above shell sprites and may cover
internal tile seams; grouping/dirty presentation belongs to TC09.

## Independent byte glyph contract

`glyphs.txt` is the complete independently authored 5×7 ASCII stroke source.
No CC, Greg Flavored, system or other font bitmap is used. `glyphs/atlas.png`
is 96×144 RGBA: 16 columns × 16 rows, 256 cells of 6×9 pixels. White opaque
foreground is tintable; the background is transparent. No rich text is
interpreted by this asset pipeline.

- ASCII bytes 32..126 have separate glyphs; byte 32 is blank.
- Mosaic bytes 128..159 subtract 128; bits 0..4 select row-major 3×3 subcells,
  with the last bottom-right subcell always transparent. Byte 128 is blank.
- All other bytes contain the same outlined replacement box (one cell).

`art.glyphs[byte]` is zero-based (0..255), with filename, width=6, height=9,
x=`(byte%16)*6`, y=`floor(byte/16)*9`, scale=1. Register named SpritePrototypes
for runtime rendering; names are owned by the monitor integration, not this
asset table. Runtime palette tint selects foreground; paint backgrounds
separately. At default zoom Factorio uses 32 screen pixels/tile: because the
API uses 64 logical units/tile, a scale-1 cell needs runtime x/y scale 0.5
(or a copied glyph sprite scale 0.5). Multiply by the API text scale, use
cell-centred world positions, and rotate glyph orientation with the group.
Do not double-apply the half scale. This is a concrete coordinate contract,
not verified native-client zoom/touch evidence.

## Regenerate and check

Python 3 stdlib and Git (only for source re-import) are sufficient. No package,
external font, image program or network request is needed.

```sh
# Optional re-audit/re-import from pinned Git objects, not checkout contents:
python assets/audit_sources.py --greg-repo /path/to/greg-flavored \
  --cc-repo /path/to/cc-tweaked --output assets/source-audit.json
python assets/import_sources.py --greg-repo /path/to/greg-flavored
# Normal offline regeneration from shipped original blobs:
python assets/generate.py
# Fresh external destination; also makes an isolated asset test mod ZIP:
python assets/check.py --output /outside/git/tc02-check
# Reuse TC01's harness, after integration makes tools/smoke.py available:
python tools/smoke.py --factorio /path/to/factorio \
  --archive /outside/git/tc02-check/tweaked-computers_0.0.1.zip \
  --output /outside/git/tc02-engine --mode base --fixture assets.engine-contract
```

Encoding is RGBA8, PNG filter 0, zlib level 9, no ancillary chunks. The manifest
records zlib's version; reproducibility was verified byte-for-byte in this
runtime. Preserve original bytes and generated output/manifest hashes when
changing toolchains. `check.py` verifies all 146 PNG outputs, source/decoded
alpha hashes, transparent margins, all glyph masks, exact offline regeneration
and source/output/notice ZIP inventory. It produces an external asset contact
sheet only, not a client screenshot. Test fixture files are not gameplay entry
points and must not be substituted for production data/control.

Actual Factorio 2.0.77 base-only smoke passed: all 461 sprite frame/icon/glyph
registrations were drawn and destroyed in headless Lua through the exact ZIP.
This checks schema/resource paths and render-object operations; headless mode
does not prove GPU PNG loading, alignment, zoom readability, touch, rotations
or multiplayer. Those client checks are deferred to the user, not a blocker.
The final integration card owns the complete installable gameplay archive and
base/Space Age final smoke. No client was started and nothing was published.
