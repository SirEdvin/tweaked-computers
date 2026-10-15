# RD2 industrial artwork verification

Target: Factorio 2.0.77, base alone and Space Age. This milestone supplies the
complete art family, not a new API/runtime, a release or native-client acceptance.
The development package retains its baseline version until RD6 publishes 0.1.2;
do not replace the public alpha 0.1.1 artifact or use this ZIP on a valuable save.

## Design and source boundary

The approved silhouette direction is implemented as original project MIT art:
low sloped computer/keyboard console, ribbed cartridge cabinet, thin modular
monitor, one continuous three-bay signal instrument and two-bay dial/terminal
controller. Their icons depict those same bodies. All directions have independent
projected geometry, grounded shadows and compact off/unpowered/powered/fault/
activity states. Fine deterministic cast-metal grain and restrained brass/amber
accents replace repeated pale computer cubes and letter badges.

The first image pass led to a larger computer screen, cabinet wall cartridges,
more readable instrument rails/grilles and chamfered shadows. The enlarged sheet
was widened so long devices are not clipped. A raster regression guards Pillow's
inclusive rectangle endpoints: the monitor panel is precisely 64×64 and its glass
60×60, not 65×65/61×61. The two-unit bezel and logical API/touch transform remain.

`assets/industrial.py` is editable source; `assets/generate.py` is the deterministic
export; `assets/requirements.txt` pins the observed Pillow version. All source,
output, decoded-pixel, alpha and notice hashes are in `assets/manifest.json`.
Historical Greg Flavored source blobs/notices are unchanged and verified, but no
upstream artwork is sampled. Full developer instructions are in
[assets/README.md](../assets/README.md).

Socket geometry comes only from RD1 production Lua. `assets/export_layout.py`
runs `assets/layout-data.lua` in the exact engine and exports all role centers,
contacts and colors to `assets/socket-layout.json`, retaining round-trip numeric
precision. The art generator refuses a stale definition hash. No physical socket,
authorization rule, recipe/footprint, scheduler limit, state/draft or service path
was changed to fit the new images. `scripts/device-art.lua` is unchanged; its
existing status identities now resolve to the new masks.

## Reproducible focused checks

Use fresh external directories; the same gameplay archive must be tested and
handed off. The artifact/evidence hashes and output paths are recorded in the
Kanban handoff, not embedded recursively in this packaged document.

    python3 assets/generate.py
    python3 assets/check.py --output /outside/repo/rd2-static
    python3 assets/contact_sheet.py --output /outside/repo/rd2-contact
    python3 -m unittest discover -s tools -p test_build.py -v
    python3 tools/player_docs.py --check --report /outside/repo/rd2-player-docs.json
    python3 tools/build.py --output /outside/repo/rd2-artifact
    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive /outside/repo/rd2-artifact/tweaked-computers_0.1.1.zip \
      --output /outside/repo/rd2-art-engine --fixture tests.art_engine \
      --data-fixture tests.art_data
    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive /outside/repo/rd2-artifact/tweaked-computers_0.1.1.zip \
      --output /outside/repo/rd2-physical --fixture tests.redesign_engine \
      --data-fixture tests.redesign_data --production-context --cold
    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive /outside/repo/rd2-artifact/tweaked-computers_0.1.1.zip \
      --output /outside/repo/rd2-factory --fixture tests.integration_engine \
      --production-context --cold

The art fixture checks installed body/shadow/icon/status descriptions, all 64
exact contact coordinates and 160 status frames against production definitions.
It registers and draws/destroys 461 native sprite objects, then checks 160
status-selection cases on 20 real shells and their cleanup. State flags in that
focused fixture are deliberately set by the test; it is not a simulation of 160
power outages. The physical/factory cold suites separately exercise actual
wiring, private power drain/outage, mark/cancel state, role isolation, authoring
(model/table-backed player input), saved source and factory/display effects.
Cold saves reload in separate localhost-only processes with bounded console
shutdown; success is not inferred from a create-only run.

Static checks include all 146 PNGs and exact offline regeneration, precise native
contact pixels, five distinct north alpha silhouettes, monitor panel/interior/
bezel bounds, at most nine lit status pixels/frame, all 256 glyph slots, retained
notice/source hashes and exact gameplay ZIP image inventory/bytes. Alpha-mask
uniqueness alone is not the visual design review: complete ordinary/enlarged,
icon, socket-overlay and all-status sheets are inspected separately.

## Contact sheets and native boundary

`assets/contact_sheet.py` outputs an HTML index, machine-readable inventory and:

- `family-ordinary.png`: every direction at 32 pixels/tile.
- `family-enlarged.png`: every direction at 128 pixels/tile.
- `socket-overlay.png`: actual exported red/green contacts and auxiliary pad bounds.
- `all-status-frames.png`: all 160 device/direction/status-frame combinations.
- `icons.png`: all five icons at 32, 64 and 128 pixels.

The scale sheets include adjacent exact vanilla arithmetic-combinator footprint
and sprite-frame bounds from the shipped 2.0.77 prototype. They are explicitly
outlines, not fabricated vanilla sprites: the official headless distribution has
no image resources. An optional externally supplied wiki illustration is labelled
not scale-calibrated, carries a source/hash/Wube notice in the index, and is not
shipped as mod artwork. Normal offline reproduction needs no reference download.

Headless creation/draw calls verify schemas, paths, metadata and object lifecycle,
not GPU PNG loading or visual occlusion. The user owns the short native check
below. No client screenshots, hover, multiplayer, typing/focus or native red-X
visibility are claimed. RD4 still owns monitor layering/removal feedback; this
art milestone does not silently mark that work passed.

## Short user-owned native review (unperformed)

1. Place all five devices beside vanilla combinators at ordinary zoom; rotate
   each through all four directions. Confirm their functions read by form and
   inventory icons match, without repeated computer bodies or excessive pale tops.
2. Attach red and green wires to each role. Confirm both colors end on the depicted
   studs; logic Input/Network/Output and configurator Network/Factory targets stay
   distinct. The monitor contacts must sit on the bezel, not screen content.
3. Inspect a stopped/running/faulted computer and powered/unpowered peripherals.
   Check compact cues and shadows at ordinary zoom. The small fault cross is not
   a deconstruction order; check native marks separately after RD4 integration.
4. Join monitor tiles and update their cells. Confirm clean seams, unchanged cell
   pitch/touch geometry and unobscured bezel contacts. Any native X visibility
   finding belongs to the integrated RD4 review, not a headless art assertion.
