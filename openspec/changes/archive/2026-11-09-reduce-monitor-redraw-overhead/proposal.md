## Why

A 6×6 monitor that redraws the maintained `smooth-sine-chart` example every two ticks costs 6.1 ms of mod scheduler time on each redraw tick. Its p95 is 18 ms, which is more than one 60 UPS tick. A static chart on the same monitor costs about 0.05 ms per tick. A profile of 0.1.21 attributes the cost to host work, not to the guest chart code:
- The presenter creates a new sprite for each changed cell, then shows it, then destroys the old sprite.
- Each check that a monitor is available reads `LuaForce` and `LuaSurface` wrappers three times for each tile. It also proves the network connector of each tile twice.
- A compile-cache lookup builds a key that is a copy of the full program source (5.6 KB) on each callback.

Evidence: `/home/siredvin/artifacts/tweaked-computers/monitor-sine-profile-2026-11-09/`.

## What Changes

- When a prepared frame changes the glyph or colors of a cell that already shows a valid object, the presenter keeps that object. It records the new sprite and color, and applies them at publication, in the same tick as the visibility swap. A deferred, cancelled or refused frame changes no visible object. A cell that becomes blank, or that has no object yet, keeps the current path.
- Monitor availability uses `force_index` and `surface_index`, and proves the network connector of each tile one time. The result and the work charge do not change.
- The compiler cache is keyed by mode and then by the source string. No mode-prefixed copy of the source is made on each dispatch.
- The per-call service guard uses one body function for each service, not a new closure on each call.

Not changed: public Lua API, work charges, limits, settings, refusal codes, publication cadence, group synchronization, save format.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `monitor-display`: changed cells reuse their visible objects, and the changes become visible only at publication.

## Impact

- Code: `scripts/rendering.lua`, `scripts/monitor-presentation.lua`, `scripts/lifecycle.lua`, `scripts/services/monitor.lua`, `scripts/runtime/compiler.lua`, `scripts/runtime/environment.lua`.
- Tests: `tests/monitor_component_contract.lua` asserts the in-place contract, including a cancelled and a saved, ready frame.
- Storage: a staged frame can hold a list of pending changes. A frame staged by an older version has no list and uses the current path.

## API Impact

Status: none
Reason: No guest-visible function, field, argument, result, error or limit changes. Monitor content, timing of publication and work charges stay the same. Only host work changes.
Compatibility: Existing programs and saves keep working without migration.
Reviewed-source: 6bb66d63b1092832ea5e94dd4b26329bf465070653b18a9537f9c94a8e58c370
