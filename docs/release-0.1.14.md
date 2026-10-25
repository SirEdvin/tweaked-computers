# 0.1.14 ALPHA — native circuits and precise Ctrl-click

Target: Factorio **2.0.77**, base alone or optional Space Age. Back up saves and
matching ZIPs before upgrading. API **1**, compiler **2** and storage **1** remain
unchanged. This is an alpha, not a universal compatibility or performance promise.

## Complete native circuit access

Logic Handler input reads return the complete fresh native signal inventory,
without mod-defined signal-count, filter-count or prototype-name limits. All
native signal types are supported. Reads preserve native order and optional
identity fields; they no longer normalize or sort Factorio's observations.

Own-output reads query the handler's native configuration, not a saved mirror or
combined downstream network totals. Output writes must fit Factorio's native
section slot-index domain. Caller input validation, atomic refusal, power/path
checks and fail-safe ownership remain.

Subscriptions carry complete isolated native observations through sampling,
queueing and callback delivery. Generic Data transfer ceilings no longer cut off
these signal graphs. Registration limits remain 64 per computer and 1,024 globally.
Queue entries/envelope bytes, ordinary guest loops, arbitrary table growth,
string operations, explicit state/KV writes and Console persistence retain their
existing protections. Queue byte counters do not measure all native snapshot
memory, and fixed native-call charges do not establish a hard CPU or memory bound.

Compatibility: use effective identity `(type or "item", name, quality or "normal")`
and do not depend on array sorting. Existing accepted subscriptions, queued events,
output owners and native output survive upgrade without replaying program start.
Obsolete read caches and output mirrors are retired during synchronized gameplay.
See the [complete logic API](player/api/logic.md).

## Computer opening

Ctrl + left-click opens a workspace only for the exact selected registered
computer body. Empty ground, unrelated entities and private helper entities do
not open it. Native inventory transfers and position-based monitor touch remain
unchanged. Recover retained drafts through another computer's Maintenance tab;
full draft capacity still offers the safe recovery flow when opening a computer.

## Upgrade and scope

Keep the pre-upgrade save and 0.1.13 ZIP for rollback; do not load a newly saved
0.1.14 world in the old package. Program source, application state and peripheral
data are not reset. This release does **not** include the abandoned configurable
resource-policy/durable-execution rewrite.

Review also removed a duplicate authority charge from direct peripheral calls;
non-circuit calls retain their previous work allowance without raising budgets.
The focused regression fails before that fix and passes afterward.

Known legacy verification gap: the old 0.1.1 physical-conversion fixture fails its
exact role/color-edge assertion both against published 0.1.13 and this candidate.
This is not a newly introduced failure, but it prevents a claim of universal
old-save migration coverage. The populated 0.1.13 native-circuit upgrade is tested
separately; keep old saves and their matching ZIPs rather than relying on rollback.

The release combines the reviewed Ctrl-click and native-circuit changes. Its
external verification receipt records the exact archive hash, final packaged
engine checks, populated-save upgrade results, inherited hash-matched native UI
evidence and hosted CI/publication readbacks. Evidence is retained outside git at
`/home/siredvin/artifacts/tweaked-computers/release-0.1.14-2026-10-25/`.

No new connected-multiplayer campaign, exhaustive third-party mod-pack test or
representative GPU benchmark is claimed for this patch. Earlier native visual
checks remain finite evidence, not manual user acceptance or a hardware guarantee.
