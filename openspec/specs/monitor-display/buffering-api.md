# Buffered monitor Lua API contract

Normative API version 1 companion to [monitor-display](spec.md), the [terminal methods](lua-api.md) and [peripheral-network](../peripheral-network/spec.md). Buffering is available in the current candidate, not older 0.1.4 archives. Retained receipts identify the executed examples and evidence boundaries.

## Compatibility and automatic buffering

All existing monitor methods, signatures, dot-call rules, argument validation, aliases and exact return arities remain as documented in `docs/player/api/monitor.md`. No method gains a hidden yield. Successful calls mutate the shared terminal model before returning; reads and later authorized writers see that model, not an older displayed image. Earlier successful calls survive a later error or callback fault. The callback is not a transaction.

After each synchronized tick's callback phase, ordinary monitors automatically offer a snapshot of their latest model. Multiple calls coalesce before snapshot sealing. A started presentation keeps its own fixed snapshot; newer pending snapshots can replace each other, not the frame already being prepared. Existing programs require neither registration nor flush to receive complete per-monitor presentation.

A snapshot represents all terminal state at its seal boundary, not knowledge of the producer's animation. Writing four rows and returning leaves those four rows plus the previous remaining rows in the new terminal state. The host cannot infer a later application-level finish. This change adds no `flush`, `beginFrame`, `endFrame`, `term.redirect`, `window` global or CraftOS compatibility claim.

## Supported geometry and buffer sizing

Each logical display can be any complete rectangle with local width W and height H independently in 1..6 tiles. This includes 1×1, 1×6, 3×6, 6×3, 6×1 and 6×6, not only square presets. All existing half-step text scales from 0.5 through 5 and cardinal orientations remain supported. Irregular/oversized walls retain deterministic rectangular partitioning; this is not support for one L-shaped framebuffer.

Query `m.getSize()` for the actual character grid. The existing geometry formula remains:

```text
columns = max(1, floor((64*W - 4) / (6*scale)))
rows    = max(1, floor((64*H - 4) / (9*scale)))
cells   = columns * rows
```

W/H are display-local axes, not unrotated world X/Y. Allocate and charge snapshot/staging work for these actual dimensions; the larger capacities below are ceilings, not a requirement to allocate/pad every screen to 6×6. Derive row strides, clipping, cursor and object positions independently for every screen. Equal tile area does not imply equal columns, rows or cell counts.

| Tile dimensions | Scale | Character grid | Cells |
| --- | --- | --- | --- |
| 1×1 | 1 | 10×6 | 60 |
| 1×1 | 0.5 | 20×13 | 260 |
| 3×6 | 1 | 31×42 | 1302 |
| 3×6 | 0.5 | 62×84 | 5208 |
| 6×3 | 1 | 63×20 | 1260 |
| 6×3 | 0.5 | 126×41 | 5166 |
| 6×6 | 1 | 63×42 | 2646 |
| 6×6 | 0.5 | 126×84 | 10584 |

Automatic buffering supports every such admitted display, including the maximum 10,584-cell screen. A synchronization selection can mix shapes, scales and orientations, subject to the sum of actual cells and normal force/surface/path rules; it does not require equal resolutions. Physical tile dimensions and the count of independently selected logical displays are different limits.

## Selection API

Both methods are strict dot calls on the existing `peripheral` namespace, with normal active-run guards and work admission. There are no colon-call variants.

Saved-program selections belong to the active run. The independent
[Console contract](../console-shell/lua-api.md) permits the same synchronous
selection/status methods under its shell-session principal, even with the saved
program stopped. It shares the same ledger and ownership-conflict checks; no
selection grants a shell callbacks, background execution or privileged access.

| Signature | Exact returns | Contract |
| --- | --- | --- |
| `peripheral.setMonitorSyncGroup(members)` | zero values | Atomically select/replace this run's single group; `{}` clears it. No framebuffer or wrapper is returned. |
| `peripheral.getMonitorSyncGroup()` | exactly one `MonitorSyncStatus` table | Defensive plain snapshot of selection, progress and the latest release/blockage reason. Does not drive rendering or retry a proof. |

`members` is a dense 1-based array of records containing exactly `{name=PeripheralName, wire=Wire}`. Names are nonempty bounded exact opaque names; wire is exactly `"red"` or `"green"`. No facades, coordinates, automatic wire fallback, extra keys, functions, cycles, metatables, holes or mixed array/map values are accepted. Empty `{}` explicitly means an empty selection. Nil is not a clear operation.

Every supplied path is validated, including redundant entries. Deduplicate by resolved logical identity, not physical tile or wire. For duplicate valid paths to the same identity, red takes precedence; otherwise retain green. Sort the canonical member array by exact logical name. The retained binding is explicit: later failure does not switch colors behind the program's back. A canonically identical registration is idempotent and preserves pending work, round participation and sequence.

Registration requires currently reachable powered monitors, one force/surface and valid current identities. Check all final members and reserve capacity before changing the old selection or cancelling its pending work. A monitor already selected by another run refuses the new registration; this is an explicit presentation-configuration conflict, not an exclusive claim on writing its terminal. Replacing a different valid selection cancels its unpublished epochs as a whole, leaves every old visible image/model intact, starts a new selection sequence at zero, and waits for fresh participation. Clearing releases members to independent automatic presentation and clears the selection diagnostic.

## Update rounds and group publication

- After registration or a seal, each member needs at least one successful mutating terminal call before the next round can seal. This includes cursor/color/scale/palette setters, clear/scroll and writes; getters do not participate. A successful no-op mutation counts as participation without requiring native sprite changes. Calls by any currently authorized writer count; drawing rights remain shared.
- Once all members have participated, seal their current models together at a post-dispatch boundary. Participation resets for the following round. Capture the latest current state at that boundary, not each member's earlier first write.
- Prepare all member images while their old complete images remain visible. Publish all members in the same simulation tick with one selection-local sequence and recorded tick. No member publishes early because it is small or ready first. A static member that is never mutated deliberately holds the round; choose only screens intended to advance together, or repeat a cheap unchanged setter for a deliberately unchanged member.
- Keep a bounded newest pending snapshot vector behind an admitted immutable vector. New writes do not continually restart an admitted frame. Sequence values can skip if pending vectors coalesce; `presented_sequence` only advances after actual complete group publication.
- This barrier aligns presentation epochs, not independent producer clocks. Programs drawing one animation on several screens must calculate one shared phase/data sample themselves. Multi-callback row batching still needs a producer change to avoid intermediate application images; no debounce duration guesses when a drawing is finished.

## Status data

```text
MonitorRef = { name: string, wire: "red" | "green" }
MonitorSyncStatus = {
  members: MonitorRef[],
  status: "none" | "waiting" | "preparing" | "blocked",
  presented_sequence: nonnegative safe integer,
  presented_tick: Tick?,
  diagnostic: { code: string, message: string }?
}
```

`none`: no selected group, members empty, sequence zero and tick absent. A definitive release can retain one bounded diagnostic until clear or successful reconfiguration. `waiting`: selected but no sealed eligible replacement; some or all members have not participated. `preparing`: at least one sealed vector is queued, being prepared or waiting for commit credits; it is not an acknowledgement of visible changes. `blocked`: temporary unavailable power/proof/geometry capacity prevents publication, with a typed diagnostic. Blockage takes priority over preparing, which takes priority over waiting. Sequence starts at zero and tick is absent until first publication. The snapshot exposes no native handles, host cell arrays, executable values or mutable ownership records. There is no new event type or blocking wait API.

## Limits and errors

Publication headroom is demand-driven, not a permanent maximum reservation: retain a 60000-unit baseline, permit trusted requests up to 160000 units within the existing 200000-unit shared maintenance ceiling, and require at least one baseline-reservation opportunity between boosts. Freeze each actual tick's reservation before maintenance; later requests cannot change it or refresh spent credits. Persist this decision across reload. Topology indexing/ordering/rectangle preparation is resumable and prepaid, so it can advance on those service opportunities. These are host scheduling rules, not new guest frame-control methods or a waiver of native-client acceptance.

Queried monitor safety capacities are:

| Key | Value / meaning |
| --- | --- |
| `width_tiles`, `height_tiles` | 6 each, independently; every complete rectangular size within these bounds is supported |
| `cells` | 10584 per logical display, covering 6×6 at scale 0.5 |
| `sync_group_refs` | 8 supplied entries before logical deduplication |
| `sync_group_members` | 4 distinct logical monitors |
| `sync_group_cells` | 10584 summed actual current character cells, allowing four 6×6 scale-1 screens, a single maximum-resolution 6×6 screen or mixed sizes/scales within this total |
| `sync_groups_per_run` | 1 selected group |
| `render_snapshot_cells` | 80000 cells in newest pending snapshot vectors across the world |
| `render_staging_cells` | 10584 globally admitted in-flight cell slots; actual jobs use only their own geometry |
| `render_retired_cells` | 10584 queued retired cell slots, excluding invalid fronts still accounted as owned fronts |
| `render_staging_frames`, `render_retired_frames` | 256 each; frame-record backpressure also applies when tiny grids fit the cell cap |
| `render_commit_objects` | 42352 visibility operations per single admitted publication, conservatively 4 × summed cells plus old/new panel/cursor allowance for four members |
| `render_commit_work` | 160000 hard whole-commit ceiling including preflight, within the existing 200000-unit shared maintenance ceiling; the native/witness reference probe consumes 147384 and remaining coordinator checks must also fit before publication |
| `render_object_limit` | 203872 monitor-presentation-owned native objects: 2 × 80000 front cells + 4 × 10584 staging/retired cells + 6 × 256 panel/cursor allowances |
| `render_retained_cells` | 362336 conservative model/render cell slots: 4 × 80000 + 4 × 10584; includes working, visible, pending, admitted and retired representations, not byte-size accounting |

Raise the physical dimensions from 4×4 to 6×6 and per-display cells from 4704 to 10584. Retain the existing 256 world tiles, 80000 aggregate model cells, 1024 preparation/cleanup checks per tick, and callback/shared host/maintenance ceilings. The render reservation can be rebalanced only after proving both whole-publication admission and non-render maintenance progress within that shared ceiling; no unmetered swap or automatic aggregate-quota increase is authorized. The 256-tick stable-world render target remains provisional until measured; group waiting for participation/power/authority is explicitly not a ready-frame latency claim. Limits are queryable through monitor `getLimits()` (including when reachable but unpowered); expose group-selection bounds through `computer.getLimits()` as well so no monitor is required just to discover API capacity. Four maximum-resolution 6×6 screens are not promised in one group: four scale-1 screens fit the combined-cell limit; four scale-0.5 screens do not. Mixed configurations are admitted by actual summed cells, never by a square/equal-size restriction.

| Error | Selection behavior |
| --- | --- |
| E_ARGUMENT | Wrong arity/type, nil, malformed/sparse members, unknown key, invalid explicit wire or malformed name |
| E_UNREACHABLE | A supplied logical name/path cannot currently be resolved; no coordinate or color fallback |
| E_WRONGTYPE | Supplied reachable peripheral is not a monitor |
| E_UNPOWERED | A selected member is unpowered |
| E_NETWORK_PENDING | Complete topology/identity proof is deferred; retry in a later callback |
| E_LIMIT | Raw input or proof complexity exceeds a per-operation bound |
| E_CAPACITY | Distinct-member, combined-cell or retained-capacity admission fails |
| E_BUSY | A member belongs to another run's selected presentation group, or checked maintenance work must defer |

Existing E_NOT_FOUND active-run guards and fatal guest budget controls remain unchanged. Ordinary selection refusals preserve both the old group and all model/presentation state. Work for full validation, copying, admission and cancellation is reserved before publication of the new selection. Ordinary monitor-call rejection retains existing per-call atomicity, including when snapshot copy-on-write is needed.

## Lifecycle

Selection ownership is `(computer_id, run_id)` plus exact member identity/generation/path bindings; it is not a saved facade. Ordinary save/load preserves ownership, participation, immutable vectors, progress, last acknowledgement and spent credits without executing source. Computer power loss suspends its selection without clearing it; restoration revalidates before publication. Monitor power loss hides that monitor, retains its model/front and blocks group replacement until the whole group qualifies again.

Stop, fault, source replacement, computer removal, definitive selected-path revocation, or removed/absorbed member identity releases the entire selection and cancels its unpublished vectors. Readback retains a bounded reason where the owner remains addressable. No cancelled vector partially publishes. Accepted shared models and already visible frames are not erased; released members resume ordinary independent automatic buffering. A temporary pending proof blocks rather than masquerading as definitive detach. Other authorized writers keep their normal model access throughout.

A retained logical identity with changed geometry/scale invalidates old staging and resets participation. If it still fits the group limits, rebuild against its new geometry; if not, keep the whole group blocked with E_CAPACITY until it fits or is reconfigured. The scale operation itself retains its existing valid-domain behavior and model/resize notification semantics. Old-geometry output may hide during invalidation; touches are ignored while visible/current grid geometry differ. Existing Ctrl-click, reach, force/surface, power, layer and feedback rules remain binding.

Upgrading the grouping policy reevaluates existing walls through paid synchronized work even when their tile positions are unchanged. A wall previously split by the 4×4 ceiling can merge into a 3×6 or 6×6 display. Preserve the normal surviving-anchor/settings rules; absorbed logical names detach and changed character dimensions clear the resulting buffer and notify resize. This is not guaranteed preservation of images across a geometry-changing merge. Ordinary load must not mutate storage, execute source or rebuild render objects merely to force the new partition.

## Illustrative selection example

This start handler selects all discovered logical monitors, within the queried limits. It does not itself draw or implement an animation. After selecting, the program's drawing handler uses the existing monitor methods, touches every group member per round, and computes one shared animation phase. The exact example and a real plotted update must be exercised during implementation; it is not claimed runnable on 0.1.4.

```lua
return {
  api_version = 1,
  handlers = {
    start = function(event)
      local members, seen = {}, {}
      for _, wire in ipairs({"red", "green"}) do
        for _, name in ipairs(peripheral.getNames(wire)) do
          if not seen[name] and peripheral.getType(name, wire) == "monitor" then
            seen[name] = true
            members[#members + 1] = {name = name, wire = wire}
          end
        end
      end
      peripheral.setMonitorSyncGroup(members)
      computer.log("Selected synchronized monitors")
    end
  }
}
```

Acceptance mapping: every rectangle/scale/orientation and mixed-size allocation → monitor-display geometry scenarios; automatic unchanged-method behavior and multi-callback limitation → automatic/compatibility scenarios; group barrier, no-op participation and credit refusal → synchronized/bounded scenarios; dual-color deduplication, mixed-size selection, shared writers, rejection atomicity and defensive readback → peripheral-network scenarios; outage/resize/revocation/stop, policy-upgrade regrouping and cold progress → lifecycle/upgrade requirement sets. Native-client visual acceptance remains separate from all headless assertions.
