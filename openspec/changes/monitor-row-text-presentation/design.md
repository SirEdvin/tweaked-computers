# Design

## Context

- `scripts/monitor-model.lua` stores one `{byte, fg, bg}` table per cell. `blit` loops in Lua over each character and marks damage per cell.
- `scripts/rendering.lua` is the presenter backend. Each cell has a background fill sprite and a glyph sprite. `scripts/monitor-presentation.lua` drives the work in this order: seal snapshot → admit → prepare (per damaged cell, hidden objects or in-place mutation lists) → commit (visibility swap plus mutations in one tick) → bounded retirement. All admission is counted in cells.
- In the spike, building the row string took most of the row-text time when it was done per character in Lua. Per-run native `string.find` plus `gsub(segment, '.', MAP)` cut it by about half. Setting `.text` itself costs about 5 µs for rich text and about 0.8 µs for plain text.
- Pinned engine facts (2.1.23): a mod font is declared in `locale/<lang>/info.json` (`"font": {"tc-term": [...]}`) together with `FontPrototype{from='tc-term', size=36, filtered=false}`. It loaded in the `en` and `ru` locales with only the `en` file. Text and rectangle `LuaRenderObject`s have no writable `render_layer`. Text drew about 6 screen pixels below its target at zoom 1, 2 and 4.

## Goals / Non-Goals

**Goals:**
- Make native object count and per-frame presenter work grow with rows, not cells.
- Remove native object creation from preparation, so a cancelled frame owns nothing.
- Keep every observable terminal, publication and lifecycle contract.

**Non-Goals:**
- No change to guest call overhead (sandbox, call guards). That is a separate lever.
- No graphics mode. That is `monitor-graphics-mode`, which builds on this font.
- No change to limits, work-charge rules or publication cadence.

## Decisions

### D1. Row strings in the model
The model keeps `rows[y] = {text, fg, bg}`, with three strings of exactly `width` bytes each. Colours are stored as hex digits, which are the same bytes `blit` receives.
- `write` and `blit` are string splices: `sub .. new .. sub` on each of the three strings.
- `clearLine`, `clear` and `scroll` operate on whole rows.
- Damage is a set of row indices plus the existing full-damage epoch.
- Snapshots share the row tables: they are immutable after a write replaces them, so a snapshot needs no grid copy.
- A `model.cell(m, x, y)` accessor returns `{byte, fg, bg}` for fixtures and the inspector.
- Work charges stay per byte, as today. Charges are computed from the same lengths, so they are unchanged.

Alternative: keep cell tables and build the row strings at presentation time. Rejected, because that per-character Lua loop is the cost the spike measured (5.3 against 2.5 ms/frame at 126×84).

### D2. One rich-text glyph object per row
For each changed row, the presenter walks the foreground runs with `string.find(fg, '[^c]', x)`. For each run it emits `[color=r,g,b]`, then `gsub(sub(text, x, e), '.', MAP)`, then `[/color]`. `MAP` maps each byte to the UTF-8 encoding of U+E000+byte. The rich-text tags are produced only by the host. Guest bytes become private-use characters, so they can never form a tag.
- A row whose text is all spaces has no glyph object.
- Palette colours are taken from the snapshot, so a palette change invalidates the whole frame, as today.

Alternative: one plain text object per (row, colour). Rejected: the spike measured 7.3 ms/frame against 5.3 at 126×84, and that variant needs more objects.

### D3. Backgrounds as reused filled rectangles, with a text fallback
Each background run is a `draw_rectangle{filled=true}`. A changed row reuses its rectangles in order: it sets `left_top`, `right_bottom` and `color` in place, then creates or destroys only the difference in run count.

The fallback depends on gate D6. If the text offset cannot be removed, backgrounds become a second rich-text object per row. It uses a full-block glyph that only the font contains, at code point U+E100 (the atlas has no full block: byte 159 lights five of six mosaic cells). Then both layers share the engine's text offset. With the fallback, the object count is two per row whatever the run count.

### D4. Prepare builds data, commit applies it
- Preparation produces, for each damaged row, `{y, text_string, runs}`. It is plain Lua data, charged as work and saved with the job, and it creates no native objects.
- Commit prepays the bounded number of native writes, using the existing `render_commit_objects` and `render_commit_work` ceilings. In one tick it then sets texts, updates rectangles, creates missing row objects and destroys surplus ones.
- A frame that is deferred, refused or cancelled therefore has nothing to retire. Old-format fronts still go through the existing bounded retirement queue.

Alternative: keep hidden staging objects. Rejected, because they double the object churn and the retirement work. With rows, a full frame is at most `height × (1 + runs)` objects, which fits the existing commit ceilings. The worst case is a 126-run checkerboard, about 10.7k rectangles. That is below today's up to about 21k visibility writes per full-frame swap.

The existing cell-denominated admission (`render_staging_cells`, `aggregate_cells`, `render_snapshot_cells`) is kept unchanged, as safety envelopes counted in cells. Only the loop unit becomes rows.

### D5. Font asset and geometry
`tools/terminal_font.py` generates `assets/fonts/tc-term.ttf` from `assets/glyphs/atlas.png`. It uses fontTools, a development-only dependency. The generated TTF is committed.
- 128 units per pixel, em = 9 px, advance = 6 px;
- one contour for each horizontal pixel run.

The font is registered in `assets/manifest.json` as a derived output of the atlas. The existing `tools/build.py` hash check therefore covers it without needing fontTools. The derived-artwork inventory check is extended from `sprites`, `icons` and `glyphs` to `fonts`. A stale or unlisted font fails the build, so the font never drifts from the sprite glyphs. Text is drawn with:
- `scale = 0.125 × textScale` (font size 36);
- `alignment='left'`, `vertical_alignment='top'`;
- target = the row's top-left in world coordinates through `model.world`;
- `orientation = direction/16`, as glyph sprites use today.

The panel and the cursor stay fill sprites with their current render layers.

### D6. Spike gate before presenter work
A full-client capture (base and Space Age, zoom 0.5/1/2/4, all four directions) compares row text with the current sprites. It covers:
- font size and metrics, including OS/2 and hhea line gap, ascent and descent;
- `vertical_alignment` of top, middle, baseline and bottom;
- a compensating target offset.

If no combination stays within one screen pixel at every zoom, D3's text fallback is selected, and the remaining offset against the bezel is measured and documented. The same capture checks:
- that text draws below the selection box, wires and the deconstruction marker;
- how cloud shadows affect text compared with sprites;
- loading in the `ja` and `zh-CN` locales.

### D7. Upgrade
The existing synchronized enrolment step in `monitor-presentation.lua` is extended:
- A model with `cells` converts to rows. The work is bounded and charged in maintenance, and resumable per display across ticks.
- Its front is marked as a legacy cell front. The display receives full damage, so the next frame publishes row text.
- At that commit, the legacy front's sprites are hidden and queued for the existing retirement.
- Unknown shapes fail closed with a diagnostic (spec: Row model upgrade).

`services/monitor.lua` shape validation accepts only the row shape after migration.

## Risks / Trade-offs

- [Text offset or render layer cannot be controlled] → Gate D6 runs before presenter work, and D3 provides the fallback. If text draws above native feedback markers, the change stops and the result returns for a design decision.
- [Cloud shadows dim text but not sprites] → Measure this in D6 and show it in the visual report. It is not hidden by changing sprite layers.
- [Font blurs at scale 0.5 when a glyph pixel is smaller than a screen pixel] → Show it in the D6 capture beside the sprite baseline. It is a known appearance difference.
- [Small grids gain little: 0.30 → 0.24 ms/frame in the spike] → The proposal states this. The main gains are on large grids and in object count and save size. Guest call overhead is out of scope.
- [About 20 fixtures read `model.cells`] → Migrate them all to `model.cell` in the same task group. Do not delete their assertions.
- [Rich-text parse cost at commit] → It is included in the measured 2.5 ms/frame. The matched report includes the dense workload.

## Migration Plan

Upgrade runs automatically after configuration change (D7). Rollback to an older release is not supported for saves made after the upgrade: the older code fails closed on the new row shape. This is the same as earlier storage upgrades.
