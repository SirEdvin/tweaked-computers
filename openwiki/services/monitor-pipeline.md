---
type: service
title: Monitor grouping, retained rendering and input
description: Geometric rectangular monitor partitioning, logical peripheral resolution, byte-cell state and resumable world presentation with authorized touch delivery.
tags: [monitor, rendering, grouping, input, events]
verified:
  - by: openwiki/0.7.1
    at: 2026-10-15T06:41:57.498Z
sources:
  - id: openwiki-source-6cb73c4f41436e6fd8ec0717
    resource: repo://scripts/monitor-model.lua
  - id: openwiki-source-562ddd59792f21328a7d3825
    resource: repo://scripts/rendering.lua
  - id: openwiki-source-0bf68f272e97a323da18a610
    resource: repo://scripts/scheduler.lua
  - id: openwiki-source-560d8f7667f960a94117249a
    resource: repo://scripts/services/monitor.lua
generated: { by: "hermes", at: "2026-10-15T06:41:57.498Z" }
---

# Monitor grouping, retained rendering and input

## Geometry and network identity are different

`services/monitor.lua` buckets physical tiles by surface, force and cardinal direction, sorts top-to-bottom/left-to-right/ID and greedily selects the largest complete rectangle anchored at each unused tile (fixed dimension bounds, width-first ties). Holes or irregular shapes become multiple rectangles; this is not an arbitrary connected-component screen. East/west swap logical width/height axes.

Physical discovery still traverses actual `network` wires. Only after traversal does the monitor type resolver map a reached tile to its logical group. A merged display is not a hidden wire bridge. Group availability requires all members to be live, powered, same-scope/direction, inside current geometry and backed by their owned connector.

Regrouping uses a plain retained job with signature, rectangles, cursor, replacement groups and membership. It prepares up to four rectangles per pass, waits for retired drawing generations, then commits the replacement maps together. A topology signature change invalidates the staged job. `resolve` raises `E_NETWORK_PENDING` during an uncommitted job, rather than exposing half-old/half-new membership.

A surviving anchor can retain its logical ID; otherwise a new monotonic group ID is allocated. New models inherit settings and copy cells only when resulting character dimensions match; changed dimensions start blank. A blanket assertion that every regroup always erases—or always preserves—the buffer would be wrong. Resize notifications are scheduled only where the surviving group's character dimensions change; scale has its own resize path.

## Model first, renderer second

`monitor-model.lua` owns plain byte cells `{byte, fg_index, bg_index}`, cursor, palette, colors, scale, dimensions and revision. Writes are byte-oriented, clipped to visible cells, do not wrap automatically and still advance the cursor by full input length. `blit` validates equal byte lengths and lowercase hexadecimal colors before mutation. Clear/scroll/scale reserve their bounded full-model work. Scale accepts half-steps from 0.5 to 5; dimension changes clear cells, while a scale change with equal character dimensions keeps them. British color aliases reuse the same methods.

A cell is not rich text or a native GUI string. The renderer selects the independently authored `tc-glyph-BYTE` sprite and separately paints background rectangles. Palette changes bump model revision; old cells store palette indexes so rendering observes updated colors. The geometry model shares a single logical-units/world transform with touch hit testing, including cardinal orientation and bezel margins.

## Retained dirty presentation

`rendering.lua` reserves maintenance headroom and keeps host render-object handles with the group. It compares cell byte/color/palette values plus native handle validity before replacing draw objects. A model revision triggers a bounded sweep; `sweep_cursor`/`sweep_revision` survive save/load. When a model changes during a sweep, completion restarts against the new revision instead of falsely marking it presented.

The same per-tick cell allowance covers retired-object cleanup before new presentation. A fair group cursor shares that allowance; geometry/scale changes retire old grids once and build new panels. Unpowered groups hide native draw objects and preserve model contents for restoration. Cursor blink is a separate retained draw object. These are bounded model/presentation mechanisms, not proof of GPU resource rendering, normal-zoom legibility or a measured player-input-to-visible latency bound.

## Authorized touch and coalesced resize

The custom activation handler rejects GUI events, an opened GUI, held cursor stack, missing/invalid position, uncommitted regroup and unavailable display. Cursor world position selects the tile/group rather than native entity-selection priority. It requires same player force/surface and reach to the actual tile under that position; shared inverse geometry rejects the bezel and produces one-based character coordinates.

Accepted touches enqueue a bounded retained job with player/sample tick and current running recipient identities. Notifications prioritize touch, recheck current group/player scope and current recipient run, and prove actual peripheral authority independently on red/green. Each interested subscription gets one event with available wire metadata, not duplicate events per path/tile/color. A different player interaction remains a different job.

Resize jobs coalesce later dimensions into queued events while preserving the original old dimensions and envelope identity. Before resize callback dispatch the scheduler refreshes current width/height once more, so a later committed geometry does not leave `getSize` disagreeing with the delivered dimensions. Event delivery can defer with a retained cursor; group/member changes cannot grant stale network authority.

## Extension and verification

Keep terminal mutation in the plain model, ownership/geometry reconciliation in the service and native handles in presentation. New rendering primitives must reserve work and use the same coordinate contract as input. Do not persist guest closures or turn a screen merge into discovery connectivity. Material monitor items intentionally carry settings, not obsolete group cells/cursor; see [lifecycle](../devices/ownership-and-lifecycle.md).

`tests/monitor_engine.lua` covers model calls, real headless draw objects, grouping, cold sweeps and explicitly mocked player activation. Those checks are not native player touch/focus/zoom evidence, and were not rerun during wiki-only generation. See [operations](../operations/build-test-and-assets.md).

Related: [network distinction](../network/discovery-and-authority.md), [scheduler](../runtime/scheduling-and-admission.md), [artwork/glyph contract](../operations/build-test-and-assets.md).
