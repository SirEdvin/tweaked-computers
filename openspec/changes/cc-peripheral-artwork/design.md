## Context

The Service Rack art comes from `assets/service_rack.py`, a deterministic Python rasterizer. `assets/generate.py` writes all sprites, icons, `sprites.lua` and `manifest.json`. `assets/check.py` regenerates them and requires byte identity. Native wire points come from `M.contact` and `M.points` in `scripts/device-definitions.lua`. `assets/export_layout.py` exports `M.contact` through the 2.1.23 engine to `assets/socket-layout.json`, and `tests/art_data.lua` compares that export with the native prototypes.

## Goals / Non-Goals

**Goals:**
- Ship the reviewed light-rust CC peripheral art for eight devices.
- Keep regeneration reproducible without Blender.
- Draw wires to the modelled antenna rings in every direction.

**Non-Goals:**
- New monitor art. The monitor display, touch and bezel geometry stay locked.
- New footprints, sockets or selection boxes.

## Decisions

1. **Blender renders are committed source.** Cycles output is not byte-identical across Blender versions. `art/cc_family.py` writes renders at 128 px per tile into `art/renders/`. `assets/generate.py` downscales them with Pillow Lanczos to 64 px per tile and makes the shadow layer from the shadow-catcher alpha (alpha below 12 becomes 0, then alpha × 0.72, black color). The `art/` directory is outside the packaged directories, so the renders stay out of the mod ZIP. The manifest records every render as an authored input with its hash.
2. **One source for contact points.** `art/cc_family.py` writes the antenna ring centers to `art/model-points.json` as north-frame points (x east, y south, z up, in tiles). `M.antennas` in `scripts/device-definitions.lua` holds the same values. `M.contact` returns the ground point after the direction transform, raised by `z / sqrt(2)` on the screen. `M.points` puts the wire shadow at `(x + z / sqrt(2), y_ground + z / 2)`, which matches the sun of the renders. `assets/generate.py` refuses to run when the exported layout differs from the model points.
3. **Status marks reuse the existing patterns.** `industrial.status` accepts an anchor. For the new devices, the anchor is a front light of the model, projected in the same way as the contacts.
4. **Monitor unchanged.** Its body, shadow, status sheets, icon and contacts keep their bytes.
5. **Larger canvas for 1×1 devices.** Their antennas and antenna shadows reach past the 160 px (2.5 tile) canvas. The 1×1 CC devices use a 192 px (3 tile) canvas with the same pivot at the center; 2×1 and 3×1 devices keep 320 px and the monitor keeps 160 px.

## Risks / Trade-offs

- [Blender changes] → A later render with another Blender version can change pixels. The committed renders stay the reproducible input; record the Blender version in the manifest.
- [Shadow strength] → The new shadow alpha reaches about 200 (alpha × 0.72 plus Lanczos overshoot), not 100. `assets/check.py` bounds it at 210.
- [Wire ends move] → Existing wires and blueprints keep their connections; only the drawn end moves. No migration is necessary.
- [Repository size] → The 64 committed renders add about 8 MB to git, not to the mod ZIP.
