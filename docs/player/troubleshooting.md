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
- Lost draft: recovery action with no selected computer opens retained drafts.
  Copy a selected old identity into a new draft; Save and Run separately. Eight
  slots are bounded; forgetting is explicit. Save the game for durable recovery.
- State seems stale: edits/Stop/Apply retain state intentionally. Stop then confirm
  Reset State only when you want to delete that computer's application state.

## Discovery and power

Refresh Peripherals for red and green independently. Check uninterrupted same-color
mod NETWORK-to-NETWORK paths, exact force/surface and real wires, not matching
circuit values. Vanilla poles are not discovery relays; INPUT/OUTPUT/TARGETS are
not NETWORK. An unpowered device may still be present while active calls fail.
E_NETWORK_PENDING/E_LIMIT is not empty: retry later or simplify topology. A wrapper
bound to red never transfers itself to green. Replacements need fresh names.

## Logic handler

For zero input check chest read mode, INPUT color, exact type/name/quality and
getInputStatus: disconnected and connected-zero are different. `both` sums with
signed32 wrap, not physical color bridging. Filters are exact identities.

For unexpected output check native downstream condition, supply/destination,
in-flight settling, electricity, owner path and diagnostics. Stop/fault/disconnect
clears only the still-owned bank; newer writers keep theirs. getOutput reports
this bank, not all native network contributors. Do not accidentally wire INPUT
back to OUTPUT. A power resync is current input, not a replay of all lost samples.

## Monitor

Power every member, align orientation, fill the rectangle and respect 6×6 bounds.
Group changes can rename screens or clear changed-size images; re-enumerate.
Outage hides without erasing, Stop leaves the last image. Cursor can be offscreen;
query size/position and set it explicitly. write/blit never wrap or execute newline;
UTF-8 uses multiple byte cells. Blit colors are equal-length lowercase 0–f strings,
while color setters require one mask constant. All Color/Colour aliases agree.

Touch requires empty cursor, no GUI, native reach and an actual character cell;
bezel/letterbox clicks are ignored. Coordinates rotate with the display. Real
client legibility, focus and touch input are not headless-verified guarantees.

## KV database

Use type before choosing get/hgetall; WRONGTYPE is not missing. Values must be
strings; use tostring deliberately. hexists returns 0/1: **Lua treats 0 as truthy**,
so compare to 1. TTL=-2 missing, -1 persistent, 0 possibly still live. SET clears
TTL; hash edits preserve it. Separate physical databases are independent, even if
labels match; both colors to one database still share its contents.

Carried/unpowered databases keep absolute deadlines. A value can legitimately
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
