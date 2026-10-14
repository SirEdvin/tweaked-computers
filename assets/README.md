# Artwork provenance gate (TC02)

Status: **blocked on per-file provenance/permission**, not completed artwork.
No upstream PNG, model JSON, derived sprite, icon or font is shipped in this
directory. `source-audit.json` contains paths, dependency metadata and hashes,
not the original artwork. Do not register its candidate files as runtime assets.
Client verification is deferred to the user; it is not the reason for this gate.

## Candidate family and actual dependency trace

The candidate is the requested Greg Flavored **refreshed advanced/HV casing**
family, pinned at `ac6cafc3993c902e2ca95d85b501d3c7e172570c` in
`BirbIrl/ComputerCraft-Greg-Flavored`. This retains the requested art direction;
no unrelated replacement family has been selected.

The audit starts at the three advanced computer off/on/blinking models and every
advanced monitor model in that pinned pack. It resolves inheritance and texture
aliases, then identifies textures actually used by inherited element faces.
There are 23 model files, 21 candidate variants and seven used texture files.
All seven are under:

`resourcepack/refreshed/Computer Craft Greg Refreshed 1.20.1/assets/computercraft/textures/block/`

| File | Input geometry | Role | Clearance |
| --- | --- | --- | --- |
| `hv_case.png` | 16×16 RGBA | HV casing | unresolved per-file origin |
| `hv_case_pattern.png` | 16×16 RGBA | rear pattern | unresolved per-file origin |
| `computer_normal_front.png` | 16×16 RGBA | inherited computer face | unresolved per-file origin |
| `blank.png` | 16×16 RGBA | computer off glow input | unresolved per-file origin |
| `computer_front_static.png` | 16×16 RGBA | computer on glow | unresolved per-file origin |
| `computer_front_blink.png` | 16×64 RGBA | animated computer glow, plus `.mcmeta` | unresolved per-file origin |
| `monitor_normal_front.png` | 16×16 RGBA | inherited monitor face | unresolved per-file origin |

For example, `computer_advanced_off` inherits the elements of
`computer_normal_off` but overrides both casing bindings to HV. The on/blinking
models then replace the glow binding. `monitor_advanced_*` inherits
`monitor_advanced_base` and `monitor_base`: its four `monitors/advanced/...`
texture bindings are not referenced by the inherited elements. Do not mistake
those unused, absent bindings for required PNG layers or invent them. The actual
monitor face is `monitor_normal_front.png`. External parent references
`minecraft:block/orientable` and `block/cube` remain recorded, not imported.

The audit records SHA-256/size for every candidate model, used PNG, animation
metadata and permission evidence. PNG data is only inspected at its IHDR; this
is source inventory evidence, not decoded-alpha or output-sprite acceptance.

## Why the root license is insufficient here

The pinned README expressly credits original/modified models and textures from
GregTech Refreshed, GTCEu: Modern, GregTech Programmer Art and CC:Tweaked, without
a per-file attribution map. The root MIT notice identifies BirbIrl (2024), but
does not explain which selected files were inherited from which project.

The pinned CC:Tweaked `LICENSES/LicenseRef-CCPL.txt` and `REUSE.toml` are hashed
as separate evidence. The former's section 7 excludes use of its covered assets
in mods for other games. This audit does **not** conclude that all Greg Flavored
files are CCPL-covered. It concludes that the supplied evidence does not yet
establish the actual per-file origins and applicable permissions.

The script compares exact bytes against all pinned CC model JSON/PNG/animation
files under its common assets root. None of the selected files is an exact
match. That is **not** proof of independent authorship, absence of derivatives,
or permission. Re-encoding or modification alone changes a hash. Root MIT
licenses in credited projects likewise are leads, not traced selected-file
clearance. No file has been moved into a cleared list on that basis.

## Action needed to resume

Obtain a verifiable upstream attribution/permission statement mapping the seven
texture files and the 23 model files in `source-audit.json` to their actual
creators/upstream paths and revisions, and the licenses/notices authorizing
modified Factorio distribution. If any selected file derives from CCPL-covered
material, obtain cross-game permission from the relevant rights holder or ask
the user to approve an explicitly independent replacement approach. Permission
from a downstream pack author alone must not be presumed to cover someone
else's inherited material. Do not silently change the requested family.

No outbound permission request has been sent. A maintainer can use the pinned
paths and hashes in the JSON audit to make a precise request. Once evidence is
provided, record it per file, retain the applicable notices, then implement
projection, directional body/shadow/status layers, recognizable device/port
variants and item icons. Publish concrete dimensions, pivots, connector cues
and Factorio sprite-layer metadata only with actual generated outputs.

## Glyph boundary

No original CC or Greg Flavored `term_font.png` bytes have been imported.
The required independent atlas remains **not produced**, not cleared by this
model audit. Its contract is 6×9 cells, ASCII 32..126, five-bit 2×3 mosaic slots
128..159 and an outlined replacement box for all other bytes. Mosaic bits 0..4
are row-major with the last bottom-right subcell always background. The future
atlas must carry its own authored/licensed source and notice/output hashes;
no existing font's permission is inferred here. Consequently there is no
consumable glyph atlas for the monitor integration yet.

## Reproduce and verify this partial audit

Requires Python 3 stdlib, Git, and local repositories containing the exact
pinned objects. Working-tree contents are not trusted or modified. No network,
external image tools or engine/client process is used by the audit.

```sh
python assets/audit_sources.py \
  --greg-repo /path/to/ComputerCraft-Greg-Flavored \
  --cc-repo /path/to/CC-Tweaked \
  --output /outside/repo/source-audit.json
cmp assets/source-audit.json /outside/repo/source-audit.json
```

`source-audit.json` intentionally has empty `cleared_runtime_assets` and
`distributed_derived_outputs` lists. It cannot authorize a build or satisfy the
sprite/glyph acceptance gate. Runtime sprite regeneration, decoded-alpha checks,
output and notice packaging, engine sprite registration, and user-deferred
client alignment/zoom remain outstanding; there are no fabricated engine or
visual results. The absence of uncleared binaries is enforced by keeping this
partial directory metadata/script/documentation-only.
