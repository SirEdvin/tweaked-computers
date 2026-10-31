# Troubleshooting and safe recovery

Start with the first diagnostic, not the last cascading failure. Record mod/engine
versions, source revision, error code and actual port/color wiring. Back up the
save before manual repair; redact secrets or private source literals before reports.

## Computer and editor

- Cannot open: clear the cursor and Ctrl + left-click the visible computer body.
  Ordinary clicks do not open workspaces. Check the shared interaction binding in
  Controls, force, surface, reach and permissions. Use native
  buttons while typing. Graphical focus/control delivery remains alpha testing.
- Save changed nothing: Save changes committed source only. Apply/Run activates
  the displayed saved revision after validation. Unsaved text is never run implicitly.
- Conflict/E_BUSY: open Maintenance → Review current saved source, then explicitly Rebase (keep draft) or Reload
  (discard draft); a second intervening save requires another review.
- Fault: inspect original line/column and active revision. Invalid syntax/subset
  needs repair; `E_BUDGET` needs less per-callback work, not pcall/busy loops or
  increased caps. Divide useful work across named timers. A healthy neighbor's
  scheduling does not imply your callback can do unlimited work.
- Lost draft: Ctrl+left-click another accessible computer, open Maintenance and
  review/copy the retained old identity's draft; Save and Run separately. Empty
  ground does not open recovery. Eight slots are bounded; forgetting is explicit.
  Save the game for durable recovery.
- Empty replacement after pickup: computer items are plain hardware. Ordinary
  replacement is blank and stopped; use a source-only blueprint/clipboard copy or
  qualifying native undo. Undo restores saved source/label/state into a **new stopped
  identity**, never the removed program's execution. Private drafts remain under
  the original identity; review/copy them through another accessible computer.
- Old programmed items after update: all old `tc_computer` payloads are ignored,
  including malformed/unsupported ones. There is no item-data recovery. This does
  not reset placed computers, active programs, drafts, KV data/deadlines or monitors.
  Restore the complete pre-update save and matching old mod archive to roll back;
  a mod-only downgrade cannot recover discarded item contents.
- Undo unavailable/refused: recovery follows native per-player history and the
  exact original restoration ghost, not coordinates or a permanent archive. Keep
  valid history/ghost data and the refusal diagnostic. Old history without a
  snapshot cannot recover earlier removals; cancelling a mark before removal only
  cancels the order. If rollback cannot allocate a ghost, keep the inert,
  non-mineable body and save for host repair. Do not erase data or activate source
  to force recovery.
- State seems stale: edits/Stop/Apply retain state intentionally. Stop then confirm
  Reset State only when you want to delete that computer's application state.

## Discovery and availability

Open Peripherals and inspect its automatic updates for red and green independently. Check uninterrupted same-color
mod NETWORK-to-NETWORK paths, exact force/surface and real wires, not matching
circuit values. Vanilla poles are not discovery relays; INPUT/OUTPUT/TARGETS are
not NETWORK. Custom devices need no electricity. Unpowered native radar/speaker
may still be present while their active calls fail.
E_NETWORK_PENDING/E_LIMIT is not empty: retry later or simplify topology. A wrapper
bound to red never transfers itself to green. Replacements need fresh names.

## Logic handler

For zero input check chest read mode, INPUT color, exact type/name/quality and
getInputStatus: disconnected and connected-zero are different. Explicitly select
red or green; `both` and omitted selectors are errors. Filters are exact identities.
Legacy combined subscriptions fault safely on resume: update source and restart.

For unexpected output check native downstream condition, supply/destination,
in-flight settling, electricity, owner path and diagnostics. Stop/fault/disconnect
clears only the still-owned bank; newer writers keep theirs. getOutput reports
this bank, not all native network contributors. Do not accidentally wire INPUT
back to OUTPUT. A required legacy-upgrade resync is current input, not replay.

## Monitor

Align every member's orientation, fill the rectangle and respect 6×6 bounds; no electricity is needed.
Group changes can rename screens or clear changed-size images; re-enumerate.
Physical unavailability can hide without erasing; electrical cycling does not. Stop leaves the last image. Cursor can be offscreen;
query size/position and set it explicitly. write/blit never wrap or execute newline;
UTF-8 uses multiple byte cells. Blit colors are equal-length lowercase 0–f strings,
while color setters require one mask constant. All Color/Colour aliases agree.

Touch requires empty cursor, no GUI, native reach and an actual character cell;
bezel/letterbox clicks are ignored. Coordinates rotate with the display. Real
client legibility, focus and touch input are not headless-verified guarantees.

For a synchronized selection, inspect `peripheral.getMonitorSyncGroup()`:
`waiting` needs a successful mutator on every member, including deliberately
unchanged screens; `preparing` is not a visible-frame acknowledgement. Unavailable
owner/member proofs can block pending publication without clearing accepted content.
Inspect the diagnostic and physical identities, not the electrical network. Pending topology proof is
temporary; retry later. A definitive lost selected-color path, Stop, fault,
Apply/Run or removed identity releases the entire cohort. Remaining monitors
then present their accepted shared models independently; no green fallback or
same-coordinate retargeting occurs. Re-enumerate exact identities before selecting
again. During scale/rotation regrouping, touches against an obsolete visible grid
are ignored until a matching image publishes. Native object/layer tests do not
establish visual legibility or client input delivery for every layout.

## KV database

Use type before choosing get/hgetall; WRONGTYPE is not missing. Values must be
strings; use tostring deliberately. hexists returns 0/1: **Lua treats 0 as truthy**,
so compare to 1. TTL=-2 missing, -1 persistent, 0 possibly still live. SET clears
TTL; hash edits preserve it. Separate physical databases are independent, even if
labels match; both colors to one database still share its contents.

Carried or physically unavailable databases keep absolute deadlines. A value can legitimately
expire before replacement. Capacity refusal preserves old data; do not delete
accepted content merely to repair unsupported/corrupt metadata. Unknown formats
stay inert/refunded for recovery. Destruction destroys data; mine to preserve it.

## Configurator

NETWORK discovery color and TARGETS color are separate. Check actual native
connector isolation and same-color target relays; discovery visibility is not
authority to configure a machine. Query current capabilities and use exact enum,
prototype/quality and nested schemas. False is a value, unset is not false.
Read-only observations do not belong in set patches. Root objects replace, not merge.

Nonmanual sections are protected; shared filter changes refuse E_SHARED_SCOPE.
Explicitly detach with group="" to preserve then edit a local copy, or edit the
native group yourself. Re-enumerate section indexes after removal. Settings remain
after Stop/disconnect and do not enforce themselves after player edits.
E_ENGINE with retained recovery is not success: preserve the save and report the
failure; do not repeatedly write or erase recovery data.

## Before reporting

Try the exact small [example topology](examples.md) on a backed-up save. Include
which expectation failed (discovery, service readback, factory motion, editor or
actual graphical input), not just “computer broken”. Do not equate a headless
native-model success with graphical/audio/multiplayer acceptance. Submit a concise
[issue](https://github.com/SirEdvin/tweaked-computers/issues) with redacted source
and reproduction steps; never include account tokens or your whole private save
without reviewing it.
