# Moving, copying and recovering devices

Target: Factorio 2.1.23, base or Space Age. Native-client/connected-peer acceptance is separate from headless contracts; see the change's artifact-bound verification receipts.

## One physical device

The visible shell is the Network endpoint. All nine custom families need no electricity or power helper. The body owns only its exact Input/Output/Factory targets sockets where applicable; native radar/speaker electricity is unchanged. Rotate the body, not a helper. Mining produces one logical device item; helpers have no mining drops. Rotation retains existing helper identities and native role wires. Destruction is data loss, not mining. Stale identities never remove a replacement at the same position.

Computer items are plain hardware and keep their existing single-item stack size. Ordinary mining/replacement loses that computer's source, label and explicit state; a replacement is blank/stopped with a fresh identity. Native undo of an eligible removal instead carries the pre-removal validated snapshot through its per-player history and exact restoration ghost. It restores saved source/label/state and different formerly active recovery text, never execution, timers, callbacks, Console sessions, queues or old output ownership. Private drafts remain under their old identities. Clipboard/blueprint/clone copies carry saved source/label only, with empty state. See the [player lifecycle policy](player/lifecycle.md), including legacy-item discard and rollback.

The undo snapshot format reuses the existing 131072 conservative byte-unit envelope, 65536-unit state allowance and 16384-byte source limits without new capacity settings. Validation precedes publication; refusal retains the recoverable native history/ghost instead of truncation or a successful blank restoration. Old `tc_computer` item payloads are simply ignored, with no import/recovery. KV/monitor malformed-item protections and unsupported placed-data guards remain intact.

KV items preserve all accepted contents and absolute simulation-tick deadlines, including carried time. No timer restarts on replacement. A synchronized retained-state audit requires the key index and content inventory to match one-to-one; corrupt data is kept inert, never reclaimed or mined through a partial index. Monitor items preserve scale, palette, foreground/background colors and blink setting, not an obsolete merged-screen image or cursor. New grouping creates a blank image. Existing ordinary saves preserve live display models and logical identities.

## Upgrading from alpha 0.1.1

Back up the entire save and old mod ZIP before upgrading. The redesigned devices
use new circuit-capable shells without changing public Lua v1, logical IDs or
recipe/item names. During the mod configuration change, existing bodies are
converted only after replacement shells, required sockets and every role/color wire have
been staged. Data, absolute KV deadlines, live monitor contents, active runs and
unsaved recovery drafts are retained; conversion does not run startup again.
Existing editor sessions must be reopened against the new physical body.

Old computer-item contents are ignored on use; there is no item-data migration or
recovery. Placed records, active programs and private drafts remain intact. Old
blueprints still restore saved source/settings and native wires, not application
state or database contents. KV contents/deadlines and monitor tile settings retain
their existing item behavior. No extra socket items are required.

If conversion is refused, the old device/data/wires remain and an upgrade
refusal diagnostic is logged. Keep the backup and report the error; do not mine,
delete or reset retained data to force conversion. After the underlying cause is
repaired, conversion can be retried by a synchronized host action or a subsequent
mod configuration change. Rollback means restoring the complete backup with the
old mod, not loading an upgraded save in the old version.

## Blueprints, clones and settings copy

Physical maintenance starts from targeted events and staggered due non-power
observations, not a fresh registry discovery pass each tick. Ordinary silent
geometry/scope changes are observed within the existing 60-tick topology envelope;
operations still reject a stale binding immediately, before that observation.
Exact native destruction registrations wake only their current owned body or
socket. Deferred repair and refused observation retain demand; a fitting peer
can progress without renewing the refused owner's due tick. Clone settlement
and undo candidate cleanup stop visiting their retained state once work settles.
Ordinary cold load preserves these memberships and spent credits without an
authoritative `on_load` rebuild. Unsupported scheduling metadata stays inert.

Blueprints include saved source and labels. These can themselves contain private literals. The blueprint description visibly discloses source inclusion. Application state, KV data, active source/run, registrations, output banks and managed target IDs are excluded. Inspect or remove source before sharing a blueprint.

New blueprints attach Network wires directly to the shell; native auxiliary socket ghosts carry the other role wires, so the engine rotates their coordinates and transfers red/green wires on revival. Hidden uncraftable port tokens exist only to make these native blueprint ghosts valid; do not craft or supply additional devices for them. Building the body revives its owned helpers without consuming more items. Helpers cannot be independently mined, deconstructed or operated. Externally placed/revived unowned helpers are destroyed rather than becoming usable orphans.

Entity and area clones receive fresh identities: computers stopped with saved source/label but empty state/work, KV empty, logic zero/unowned, monitors blank with applicable settings. Native area-cloned helpers are matched to the exact new body/source family and position, then adopted under bounded synchronized maintenance; duplicate/unmatched helpers are removed. This does not authorize an unrelated entity by position alone.

Settings copy stops the destination computer and copies saved source/label, not the source computer's state or active execution. Existing destination state is retained rather than implicitly reset. Its source revision advances monotonically so an older open draft cannot silently overwrite the copied source. Monitor settings copy changes the selected group's settings. KV data and native target configuration are never copied by the peripheral's settings operation.

Force changes and force merging revoke prior run authority and stop affected computers without erasing data. Surviving native factory configuration is not rolled back. Surface deletion/clearing retires the surface's exact identities and helpers. Cross-surface machine transport in the pinned engine is tested through native cloning: LuaEntity.teleport does not support surface teleport for these machine types. No same-identity cross-surface teleport claim is made.

## Verification

Use the deterministic archive with the existing harness:

    python3 tools/smoke.py --factorio /path/to/factorio-2.1.23 --archive /outside/repo/tweaked-computers_0.1.16.zip --output /outside/repo/fresh-lifecycle --fixture tests.lifecycle_engine --data-fixture tests.candidate_data --production-context --cold --mode both

Production-context mode loads this fixed fixture at control parsing only when the isolated tc-smoke mod and its explicit startup setting are present. Exactly one mod registry owns the native build/clone/revival events; no guest loader or remote API is added. Ordinary gameplay has no on_load handler and executes no player source on load. The fixture's on_load only checks retained aliases/counters.

Headless native robot mining, blueprints/ghost revival, cloning, destruction, force/surface events and separate-process load/configuration checks are distinct from table-backed editor/player delivery. Neither is graphical/client evidence. Production work ceilings remain unchanged and provisional; explicit fixture stepping is structural lifecycle evidence, not a real-time responsiveness benchmark.
