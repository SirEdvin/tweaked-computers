## Context

See proposal.md for the measured problem. One 6×6 wall at scale 2 has a 32×21 grid. The example writes about 16 changed rows (`setCursorPos` + `blit`) for each frame. In 0.1.21 the redraw tick costs, per frame (instrumented, so about 20% high):
- About 32 monitor calls at about 100 µs each.
- The `monitor-world` render pass, about 3 ms. Of this, the presenter checks the 36 tiles of the wall two or three times for each tick, at 260–590 µs for each check.
- A compile-cache hit that does little work, but measures 0.53 ms. Most of this is probably garbage collection paid on the 5.6 KB key string.

The presenter double-buffers: each changed cell gets new hidden objects during preparation. Commit shows them and hides the old objects in one tick, and cleanup destroys the old ones later. Factorio draws the world only between ticks, so all changes made inside one tick become visible together.

## Goals / Non-Goals

**Goals:** less host time for each monitor redraw, with the same images, publication ticks, group behavior, charges and refusals.

**Non-Goals:**
- A batch row-write API. It needs a public API change and is a separate decision.
- Caching availability across callbacks or ticks. Proof reuse inside one callback already exists.
- Changing work charges, limits or the render budget.

## Decisions

### 1. Apply cell changes to visible objects at commit

`render_cell` keeps the front cell's background when only its color changes, and keeps the front glyph when its byte or color changes and the new byte is not blank. It appends `{object, sprite or nil, color}` to the frame's `mutations` list and marks the object as shared. It does not change the object during preparation.

Commit applies the list after its existing checks and after the visibility swap, in the same tick. Before it changes anything, it refuses the frame (`job.invalid`) when the front is no longer the frame's base or when an object is not valid. Mutations count against the existing commit object limit. Charges do not change: preparation still charges each cell, and the prepaid commit work already covers two operations for each cell.

A cancelled or deferred job does not touch the shared objects, because the list is only applied at commit. Cleanup does not destroy shared objects, as for the existing component sharing. A frame staged by an older version has no list, so `render_cell` uses the current path.

Alternative: keep double buffering for every change. Rejected: it creates and destroys about 30 native objects for each frame, and publication is already atomic within one tick. Alternative: change objects during preparation when the frame can commit in the same tick. Rejected: commit can still refuse after preparation, and the change would then be visible without its frame.

### 2. Cheaper availability check

`lifecycle.connector` compares `force_index` and `surface_index` instead of `force.index` and `surface.index`. `monitor.available` relied on `lifecycle.available`, which proves the red and green network connectors, and then proved the red connector again. The second proof is removed. The boolean result is the same for every tile.

### 3. Compiler cache key

The cache is a table for each mode (`program`, `shell`) keyed by the source string. Eviction keeps the same eight-entry order.

### 4. One service body

`E.service` creates its guarded body one time, and each call passes that body to `scoped`. The argument checks, snapshots, charges and errors are the same.

### API impact

None. The `lua-api` artifact is deliberately skipped.

## Risks / Trade-offs

- [A shared object is mutated while another frame still shows it] → Only the lane's own front is used as a base, and commit refuses a frame whose front changed.
- [A cancelled frame leaves a mutated object] → Mutations are applied only at commit. The component contract asserts a cancelled frame and a saved, ready frame.

## Migration Plan

No storage migration. Rollback is a code revert.
