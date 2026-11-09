## Why

Each terminal cell is drawn as two native sprites: one background and one glyph. A 6×6 monitor at scale 0.5 has 10,584 cells, so it needs up to about 21,000 render objects. The presenter loops over each changed cell, both while it prepares a frame and when it commits it. A standalone spike on Factorio 2.1.23 compared this with one text object per row, drawn in a mod pixel font. It used the `smooth-sine-chart` frame shape on one 6×6 wall, with a new frame every two ticks:

| Grid | Per-cell sprites | Row text | Objects |
| --- | ---: | ---: | ---: |
| 31×21 (scale 2) | 0.30 ms/frame | 0.24 ms/frame | 757 → 92 |
| 126×84 (scale 0.5) | 8.4 ms/frame | 2.5 ms/frame | 11,005 → 432 |

The mod font loaded in the `en` and `ru` locales. At scale 2, it matched the sprite glyphs to less than 1% of pixels. These numbers cover native drawing only: they exclude the mod's sandbox and presenter bookkeeping. Evidence: `/home/siredvin/artifacts/tweaked-computers/row-text-spike-2026-11-09/`.

The spike also found two defects. These need a gate before the change can be accepted:
- Text is drawn about 6 screen pixels lower than its target, at every zoom level.
- Text objects have no writable render layer.

## What Changes

- The mod ships a 6×9 pixel TTF font generated from the existing glyph atlas. Byte `b` maps to the private-use code point U+E000+b, so guest bytes can never form a rich-text tag.
- The terminal model stores each row as three strings (text, foreground, background), the same layout CC:Tweaked uses. It no longer stores one table per cell. Damage is tracked per row.
- The presenter draws each row as at most one rich-text glyph object, plus one background object for each run of equal background colour. A changed row keeps its objects. Commit sets their new text and colours in the publication tick.
- Preparing a frame builds only plain row data and creates no native objects. Commit applies the complete frame in one tick. Cancelled or deferred frames own no native objects.
- A spike gate resolves the vertical text offset. If it cannot be fixed, backgrounds are also drawn as text in a block glyph, so glyphs and backgrounds keep the same offset.
- Saves made before this change upgrade their cell models and per-cell fronts in synchronized work.
- The monitor performance harness gets a large-grid workload (6×6 wall at scale 0.5).

Not changed: the terminal API, glyph repertoire, colours, palette semantics, publication atomicity, synchronized groups, limits, work charges and refusal codes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `monitor-display`: rows replace cells as the presentation unit. The requirements for glyph policy, sparse presentation and coherent publication change their wording from cells to rows. A visual-alignment gate and an upgrade path are added.

## Impact

- Code: `scripts/monitor-model.lua`, `scripts/rendering.lua`, `scripts/monitor-presentation.lua`, `scripts/services/monitor.lua` (shape validation, inspector reads), `prototypes/monitor.lua`, new `locale/*/info.json` font entry and `assets/fonts/`.
- Tooling: a font generator under `tools/`, plus a `--workload dense` option in `tools/monitor_performance.py`.
- Tests: about 20 engine fixtures read `model.cells` directly. They move to a row accessor. The tests `monitor_component_contract`, `monitor_buffer_engine` and `monitor_feedback_engine` get row-identity assertions.
- Docs: `docs/monitor.md`, `docs/monitor-performance.md`, `docs/player/monitor-animation.md`.
- Saves: monitor model and front storage formats change, and they migrate on upgrade.

## API Impact

Status: none
Reason: Programs see no change to functions, arguments, results, errors, limits or events. Terminal dimensions, glyphs, colours and touch cells stay the same. Only the internal storage and the native draw primitive change.
Compatibility: Existing programs keep working. Existing saves upgrade without guest code.
Reviewed-source: b151a54b8df9d6d435783815a99cf9725f56cf21cb6b4caec8a389350c0cf186
