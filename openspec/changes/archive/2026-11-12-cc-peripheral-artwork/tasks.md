# Tasks

Each task names its verification. Run packaged engine checks with the 2.1.23 engines in fresh scratch directories. Keep logs and evidence outside git.

## 1. Art source and generation

- [x] 1.1 Add `art/cc_family.py` (light-rust CC family, eight devices, antenna contacts, status anchors) and render `art/renders/` and `art/model-points.json` with Blender 4.0.2. Verify that the renders match the reviewed previews by eye.
- [x] 1.2 In `assets/generate.py`, make the bodies, shadows, icons and technology icons of the eight devices from the renders, and anchor their status marks on the model lights. Keep the monitor outputs. Verify that the monitor outputs keep their bytes.
- [x] 1.3 Update `assets/check.py` (frozen digest, shadow bound, contact pixel on the antenna ring). Verify with `python3 assets/check.py --output <fresh dir>`.

## 2. Wire contacts

- [x] 2.1 Add `M.antennas` to `scripts/device-definitions.lua` and use it in `M.contact` and `M.points`. Export `assets/socket-layout.json` with `assets/export_layout.py`. Verify that `assets/generate.py` accepts the export and that `tests.art_data` and `tests.redesign_data` pass.

## 3. Documentation

- [x] 3.1 Update `assets/README.md` and `docs/player/artwork.md`. Verify with `tools/player_docs.py --check` and `tools/player_docs.py --check --change cc-peripheral-artwork`.

## 4. Verification

- [x] 4.1 Run the unittest discovery and `openspec validate cc-peripheral-artwork --strict`.
- [x] 4.2 Run the full-client scene in base and Space Age with all devices in four directions beside vanilla combinators, with real wires on every port. Inspect the screenshots for wire ends on the rings and visible status marks.
- [ ] 4.3 Run the release gate set of 0.1.23 on the release archive.
