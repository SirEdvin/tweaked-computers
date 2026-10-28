# Native computer lifecycle trace (2.1.23)

## Baseline, not candidate acceptance

The baseline is the immutable parent feature archive SHA-256
`8b555aff67eaff28ffbb2aa46bf93032cfc7698542ccc354fbf61c818020480c`
from SirEdvin/tweaked-computers PR #48, head
`1d02311f35d12b8b0aad288263da2d5af910a9e2`. The observer archive
`f0b34b3aa8934c5ddb7c5bef345b8e3ecbdab9c7b276d22e2ad5077f7be1ddba`
changes only `tests/acceptance_client_engine.lua`; every other archive entry
was compared byte for byte. It runs through `tools/shell_client.prepare`, with
private config/mod/write/save directories and actual XTest keyboard/mouse input
on an owned Xvfb display. The native engine is **2.1.23 build 87750 full, base**.
The observer sets only a `trace_probe` history tag to establish native tag
transport; it does not implement snapshot restoration or alter production
handlers. This diagnostic tag is not a candidate feature pass.

Durable evidence directory:
`/home/siredvin/artifacts/tweaked-computers/openspec-campaign-2026-10-27-3b5667a/t_6404c3a9/baseline-trace/`.
`ledger.json` inventories exact hashes; `base/actions.jsonl` records 49 native
action groups and the JSONL observer records 130 event/state observations.
`base/shutdown.json` verifies exit 0, Goodbye and no forced cleanup. Failed
observer pilots are separate scratch cases, not accepted trace evidence.

## Actual observations and reproduction

- Ctrl+C selects the left computer; Ctrl+V creates its source-tagged ghost on
  empty ground. A fresh hardware item builds saved source `-- saved 1`, label
  `computer-1`, empty application state, stopped. **This case already passed**;
  no blueprint event resolver defect was established.
- Actual right-button mining invokes `on_pre_player_mined_item`, then
  `on_player_mined_entity`. The old registry record exists before the latter's
  production cleanup. The native removal action is not yet in the undo stack
  during either callback; it is present at the next tick.
- Ctrl+Z builds the exact restoration ghost and raises `on_built_entity` **before**
  `on_undo_applied`. A tag written on the native removal action is supplied in
  that ghost's tags and the applied action. The opposite redo action is already
  visible at `on_undo_applied`; it is a `built-entity` for `entity-ghost`.
- Ctrl+Y removes that ghost. The original removal action and its original tags
  return on the undo side even though the inverse `built-entity` action has no
  such action tags. Repeating Ctrl+Z creates another exact tagged ghost.
- Building the undo ghost with the old mined item recovers the item's contents;
  building it with a fresh item produces a **blank** computer. This reproduces
  missing undo contents independently of construction material.
- A deconstruction-planner drag selects two computers. Each
  `on_marked_for_deconstruction` occurs before the native grouped action is
  inserted. Ctrl+Z before robots are enabled raises cancellation for the live
  bodies; their exact identities/data remain unchanged. Ctrl+Y marks them again.
- The fixture then changes live source/state, enables real construction robots
  in a powered roboport, and observes `on_robot_pre_mined` and
  `on_robot_mined_entity`. These have no player index. The player-attributed
  grouped mark action already exists and is taggable; data therefore must be
  captured at removal, not at marking.
- Undo after completed robot removal builds two ghosts before the applied event.
  The original action array is ordered x=5.5,9.5, but the opposite-stack array
  is ordered x=9.5,5.5. **Array indexes are not identities**. Match each operation
  token and native target scope; never carry a stack index or infer `last_user`.
- Robots can build between undo and redo; the trace contains four genuine robot
  removals across the two cycles. The subsequent clipboard ghost captured
  `-- saved 1`, but a robot consumes previously mined computer-4 material and the
  completed computer contains `-- saved 4--changed` and its application state.
  This reproduces the item-over-clipboard failure on the native robot build path.

## Handoff constraints for implementation and fixtures

Capture before lifecycle deletion. Temporarily retain only the unsettled,
player-attributed action until its native entry can be tagged; exclude preexisting
matching entries. Keep the full payload in native history, not a coordinate
recovery archive. A robot mark retains attribution only; snapshot the current
record when the robot actually mines it. Cancelling the mark must not restore or
stop the live record.

Confirm the actual ghost object delivered by the build callback against the
subsequent native applied event and its operation tag. Bind that exact object,
including native surface, force, quality and position, for construction. Ghost
copies must project saved source/label only and strip all undo authority/state.
Do not discover or overwrite a compatible occupant merely by coordinates. Cold
reconstruction must use synchronized saved associations, never on_load mutation.

These observations resolve the normal manual, grouped robot and cancellation
ordering. Same-tick input, hostile/stale payloads, refusal/rollback, history expiry,
maximum accepted contents, both cold boundaries, upgrades, connected peers and
Space Age remain candidate acceptance gates until separately exercised.
