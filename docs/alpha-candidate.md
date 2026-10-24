# Alpha candidate: installation, limits and manual checks

Historical TC13/0.1.0 receipt, retained rather than rewritten as newer evidence.
Its archive names, original monitor dimensions and deferred-client checklist below
are not the current installation or acceptance status. Use the current
[player guide](player/index.md), [effective limits](player/api/limits.md),
[SC2 native/peer acceptance](sc2-native-acceptance.md),
[SC3 representative envelope](sc3-supported-envelope.md) and
[SC4 consolidated receipt](sc4-final-acceptance.md). The five completed changes
are promoted on the review branch; historical public alpha archives stay immutable.

Target: exactly Factorio **2.0.77**, base-only or optional Space Age. This is a
complete eight-capability implementation for user testing, not a stable or
client-verified release. Public player documentation, developer OpenWiki and
Mod Portal publication are separate downstream delivery stages. Back up saves;
never assume an arbitrary newer-schema save can be downgraded safely.

## Install and run

1. Copy `tweaked-computers_0.1.0.zip` into Factorio's mods directory unchanged;
   enable Tweaked Computers and restart. Do not install the `tc-smoke` test mod.
2. Research Native circuit computers, craft/power the five device types and wire
   their named roles as in [the factory example](factory-example.md).
3. Open the computer; paste only the document inside the example's long brackets.
   Validate, Save and Run. Read status and diagnostics before adding more work.
4. Add the second computer and independent database using the shared-telemetry
   example. Observe factory movement, telemetry and the merged status display.
5. Retain the archive, `package-manifest.json` and external SHA-256/evidence report
   together when reporting issues. The internal manifest hashes every payload
   file except itself and lists the effective common integer limits.

## Configured envelope, not a real-time guarantee

These unchanged ceilings reject unsafe growth; they are provisional alpha tuning.
Successful work-unit accounting is not a CPU-time bound or measured maximum-world
input/render latency. `computer.getLimits()` and each peripheral's `getLimits()`
return defensive effective tables, including additional fields described in their
API guide. The package manifest freezes the candidate's common numeric defaults,
not the unfinished client performance gate.

| Area | Initial ceilings |
| --- | --- |
| Source | 16,384 bytes, 4,096 nodes/tokens, nesting 48; generated 131,072 bytes |
| Native callback | default work 500,000, depth 32, default allocations 81,920; work/allocation budgets are live Map settings |
| Compilation | default work 1,250,000, live Map setting; active/saved source kept separately |
| Shared actual tick | default 5,000,000 total-envelope units; default 200,000 reserved maintenance; both live Map settings, no extra guest pool |
| Active admission | 64 computers, 128 sampled logic handlers, 1,024 subscriptions, 128 owned banks |
| State | default 65,536 accounted bytes, 256 entries, Data depth 16; no separate total-node ceiling |
| Queue/timers | 128 queue entries / 65,536 accounted bytes; 64 timers and 64 subscriptions per computer |
| Discovery | 256 connector nodes / 512 edges; explicit complete-result refusal |
| Monitor | 4×4 tile rectangle, 4,704 cells at scale 0.5; aggregate 80,000 cells / 256 tiles; write 16,384 bytes |
| Presentation | up to 1,024 cell visits per paid rendering tick; 60,000 units reserved inside maintenance |
| Status artwork | at most 128 device visits per tick, persistent fair cursor; no added budget |
| KV | 128 keys / 16,384 content bytes; snapshot metadata reserved separately |
| Logic | 64 signal slots/filter signals; one actual-tick sample, mirrored output bank |
| Configurator | full 36 native classes / 164 inherited field entries; bounded target/schema/section operations |

The configurator ledger accounts for every field. There are 163 applicable writes
and one explicitly native-unavailable inherited asteroid logistic-connection flag,
not an unfinished adapter. Native prototype/mode restrictions and shared-group
refusal remain explicit. Consult [configurator](configurator.md) and the shipped
coverage JSON; never infer a generic arbitrary-property bridge.

Representative integration runs use six active computers, native input/output and
target circuits, shared plus independent databases and a 2×2 display. Four compute
neighbors use real 10-tick timers and useful 128-term calculations under the same
ledger. This catches starvation/hangs and source/effect integration, not the full
simultaneous maximum envelope. Focused monitor contracts separately exercise a
4×4/4,704-cell model and headless render objects; no graphical zoom claim follows.
The external run report contains actual sample counts, peaks and tick observations.
It separates stock-input-to-bank response and mock-touch response from rendered
client latency. No CPU benchmarking or client input-to-visible measurement ran.

## User-owned manual client checklist

These remain deferred; headless engine objects and table-backed input are not
proof that a native client delivered a click, focused text, loaded PNGs or joined.
Mixed OpenSpec checkboxes remain open rather than concealing these portions.

- Computer runtime (1.5, 7.1–7.3): save a live controller, reload and join with a
  second client. Compare run/state/timers, no extra startup, and peer behavior.
- Program editor (2.4/2.8, 7.2–7.3): actually type/paste and edit the threshold;
  Save keeps old behavior, Apply changes it. Check essential buttons while typing,
  focus/layout at your display scale, dirty-close recovery and two-player conflict.
- Discovery/physical roles (1.4, 2.8): click red/green wire points in all rotations;
  test complete same-color paths and the rejected mixed-color/vanilla-pole relay.
- KV (3.3/3.4): both computers see shared telemetry; a second physical database
  stays independent. Mine/replace using player and robot; carried expiry is not
  renewed, malformed snapshots never silently discard content.
- Monitor (4.3–4.5, 7.1–7.3): inspect directional layering/contrast and every glyph
  at normal zoom, 2×2 and maximum 4×4. Check palette/resize/power blank/restoration,
  non-anchor touches, borders, GUI hover/focus, rotations and two players.
- Logic (2.8/5.7): verify actual inserter transfer/cessation, native signal latency,
  both output colors and stop/fault/wire-loss cleanup without deleting newer writes.
- Configurator (5.7): compare native target GUI values with readback; test an
  ordinary pole relay on TARGETS, shared constant-section refusal/local detachment
  and applicable Space Age settings. Audible speaker playback is also unverified.
- Lifecycle/artwork (6.1/6.3, 7.3–7.4): place/mine/rotate/revive/blueprint/clone all
  families; inspect one logical item, aligned ports/shadows/status and no orphans.
  Blueprint source inclusion is intentional and visible; new clones stay stopped.

Report the exact source, diagnostic, device/wire roles, archive SHA, engine/mod
list and reproduction steps. Preserve user data before Reset, removal or upgrade.

## Lean reproducible checks

The same archive-based harness is used for integration, sandbox and focused cold
recovery, never a source symlink or a second event-owning lifecycle registry:

    python3 tools/build.py --output /outside/git/candidate
    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive /outside/git/candidate/tweaked-computers_0.1.0.zip \
      --output /outside/git/fresh-integration --fixture tests.integration_engine \
      --production-context --cold --upgrade-fixture

Both base/Space Age integrated phases run. The production-context fixture forwards
real editor text/Save/Run actions with explicitly mocked players; native factory
entities, wiring, compiler, scheduler, KV, rendering and cold persistence are real.
It executes all eight shipped documents and nine fenced source-contract documents,
plus a complete guest-export/alias inventory. Cold processes verify unchanged
retained graphs/credits and no startup configuration replay. A separate fixture-only
version change exercises configuration handling without changing production ZIP
bytes. `/quit` must acknowledge cleanly; forced cleanup is failed acceptance.

Focused existing fixtures cover compiler attacks, argument/tuple/error shapes,
source diagnostics, maximum geometry and lifecycle recovery. Their separate
process results and package inventory/hashes live in the external delivery report.
Earlier failed harness/example checkpoints are retained, not relabelled passes.
No graphical client, screenshots, UI automation or multiplayer join matrix ran.
