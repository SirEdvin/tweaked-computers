# Troubleshooting and safe recovery

Start with the first diagnostic, not the last cascading failure. Record mod/engine
versions, source revision, error code and actual port/color wiring. Back up the
save before manual repair. Remove secrets or private source literals from reports.

## Computer and editor

- Cannot open: clear the cursor. Ctrl + left-click the visible computer body.
  Ordinary clicks do not open workspaces. Check the shared interaction binding in
  Controls, force, surface, reach and permissions. Use native
  buttons while typing. Graphical focus/control delivery remains alpha testing.
- Save changed nothing: Save changes committed source only. Apply/Run activates
  the displayed saved revision after validation. Unsaved text is never run implicitly.
- Conflict/E_BUSY: open Maintenance → Review current saved source. Then explicitly select Rebase (keep draft) or Reload
  (discard draft). A second intervening save requires another review.
- Fault: inspect original line/column and active revision. Invalid syntax/subset
  needs repair. `E_BUDGET` needs less per-callback work, not pcall/busy loops or
  increased caps. Divide useful work across named timers. A healthy neighbor's
  scheduling does not imply your callback can do unlimited work.
- Lost draft: Ctrl+left-click another accessible computer. Open Maintenance.
  Review the retained old identity's draft. Copy it. Select Save. Then select Run. Empty
  ground does not open recovery. There are eight bounded slots. Forgetting is explicit.
  Save the game for durable recovery.
- Empty replacement after pickup: computer items are plain hardware. Ordinary
  replacement is blank and stopped. Use a source-only blueprint/clipboard copy or
  qualifying native undo. Undo restores saved source/label/state into a **new stopped
  identity**, never the removed program's execution. Private drafts remain under
  the original identity. Review them through another accessible computer. Copy them if necessary.
- Old programmed items after update: all old `tc_computer` payloads are ignored,
  including malformed/unsupported ones. There is no item-data recovery. This does
  not reset placed computers, active programs, drafts, KV data/deadlines or monitors.
  Restore the complete pre-update save and matching old mod archive to roll back.
  A mod-only downgrade cannot recover discarded item contents.
- Undo unavailable/refused: recovery follows native per-player history and the
  exact original restoration ghost, not coordinates or a permanent archive. Keep
  valid history/ghost data and the refusal diagnostic. Old history without a
  snapshot cannot recover earlier removals. Cancelling a mark before removal only
  cancels the order. If rollback cannot allocate a ghost, keep the inert,
  non-mineable body and save for host repair. Do not erase data or activate source
  to force recovery.
- State seems stale: edits/Stop/Apply deliberately keep state. To delete that computer's application state, select Stop.
  Then confirm Reset State.

## Discovery and availability

Open Peripherals. Inspect its automatic updates for red and green independently. Check uninterrupted same-color
mod NETWORK-to-NETWORK paths, exact force/surface and real wires, not matching
circuit values. Vanilla poles are not discovery relays. INPUT/OUTPUT/TARGETS are
not NETWORK. Custom devices need no electricity. Unpowered native radar/speaker
may still be present while their active calls fail.
E_NETWORK_PENDING/E_LIMIT does not mean empty. Retry later or simplify topology. A wrapper
bound to red never transfers itself to green. Replacements need fresh names.

## Logic handler

For zero input, check chest read mode, INPUT color, exact type/name/quality and
getInputStatus. Disconnected and connected-zero are different. Explicitly select
red or green. `both` and omitted selectors are errors. Filters are exact identities.
Legacy combined subscriptions fault safely on resume. Update source. Then restart.

For unexpected output check native downstream condition, supply/destination,
in-flight settling, electricity, owner path and diagnostics. Stop/fault/disconnect
clears only the still-owned bank. Newer writers keep theirs. getOutput reports
this bank, not all native network contributors. Do not accidentally wire INPUT
back to OUTPUT. A required legacy-upgrade resync is current input, not replay.

## Monitor

Align every member's orientation. Fill the rectangle. Keep within the 6×6 bounds. No electricity is needed.
Group changes can rename screens or clear changed-size images. Enumerate the screens again.
Physical unavailability can hide an image without erasing it. Electrical cycling does not. Stop leaves the last image. The cursor can be offscreen.
Query its size/position. Set it explicitly. write/blit never wrap or execute newline.
UTF-8 uses multiple byte cells. Blit colors are equal-length lowercase 0–f strings,
while color setters require one mask constant. All Color/Colour aliases agree.

Touch requires an empty cursor, no GUI, native reach and an actual character cell.
Bezel/letterbox clicks are ignored. Coordinates rotate with the display. Real
client legibility, focus and touch input are not headless-verified guarantees.

For a synchronized selection, inspect `peripheral.getMonitorSyncGroup()`:
`waiting` needs a successful mutator on every member, including deliberately
unchanged screens. `preparing` is not a visible-frame acknowledgement. Unavailable
owner/member proofs can block pending publication without clearing accepted content.
Inspect the diagnostic and physical identities, not the electrical network. Pending topology proof is
temporary. Retry later. A definitive lost selected-color path, Stop, fault,
Apply/Run or removed identity releases the entire cohort. Remaining monitors
then present their accepted shared models independently. No green fallback or
same-coordinate retargeting occurs. Re-enumerate exact identities before selecting
again. During scale/rotation regrouping, touches against an obsolete visible grid
are ignored until a matching image publishes. Native object/layer tests do not
establish visual legibility or client input delivery for every layout.

## KV database

Use type before you choose get/hgetall. WRONGTYPE does not mean missing. Values must be
strings. Use tostring deliberately. hexists returns 0/1. **Lua treats 0 as truthy**.
Thus, compare to 1. TTL=-2 means missing, -1 means persistent, and 0 means possibly still live. SET clears
TTL. Hash edits preserve it. Separate physical databases are independent, even if
labels match. Both colors to one database still share its contents.

Carried or physically unavailable databases keep absolute deadlines. A value can legitimately
expire before replacement. Capacity refusal preserves old data. Do not delete
accepted content only to repair unsupported/corrupt metadata. Unknown formats
stay inert/refunded for recovery. Destruction destroys data. Mine the database to preserve its data.

## Configurator

NETWORK discovery color and TARGETS color are separate. Check actual native
connector isolation and same-color target relays. Discovery visibility is not
authority to configure a machine. Query current capabilities. Use exact enum,
prototype/quality and nested schemas. False is a value, unset is not false.
Read-only observations do not belong in set patches. Root objects replace, not merge.

Nonmanual sections are protected. Shared filter changes refuse E_SHARED_SCOPE.
Explicitly detach with group="" to preserve a local copy. Then edit that copy. Alternatively, edit the
native group yourself. Re-enumerate section indexes after removal. Settings remain
after Stop/disconnect and do not enforce themselves after player edits.
E_ENGINE with retained recovery is not success. Preserve the save. Report the
failure. Do not repeatedly write or erase recovery data.

## Before reporting

Try the exact small [example topology](examples.md) on a backed-up save. Include
which expectation failed (discovery, service readback, factory motion, editor or
actual graphical input), not just “computer broken”. Do not equate a headless
native-model success with graphical/audio/multiplayer acceptance. Submit a concise
[issue](https://github.com/SirEdvin/tweaked-computers/issues) with redacted source
and reproduction steps. Never include account tokens. Do not include your complete private save
without a review.
