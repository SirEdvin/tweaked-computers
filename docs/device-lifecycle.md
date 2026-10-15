# Moving, copying and recovering devices

Target: Factorio 2.0.77, base or Space Age. This is alpha implementation; native client editing, wire selection, visuals and multiplayer usability remain user-deferred.

## One physical device

The visible shell is the Network endpoint. The body owns its private power carrier and any exact Input/Output/Factory targets sockets. Rotate the body, not a helper. Mining produces one logical device item; helpers have no mining drops. Rotation retains existing helper identities and native role wires. Destruction is data loss, not mining. Stale identities never remove a replacement at the same position.

Computer, KV and monitor items have tags and stack singly. A computer item contains saved source/revision, formerly active source/revision/version metadata, label and copied explicit state. It contains no active run, callbacks, queues, timers, subscriptions or output ownership. Replacement creates a fresh stopped identity. Save and Run remain separate. Recover Active Source in the editor shows the formerly active snapshot and Copy snapshot to Draft recovers it without saving or running. Player drafts remain associated with their old identity in the bounded recovery UI; they are not the item's committed source.

The computer format reserves 131072 conservative byte units, independently of the 65536-unit application-state allowance and each 16384-byte source limit. State is validated and its accounting reconstructed before publication. Unknown/malformed item formats are refused with the material item refunded, not truncated or silently reset. Unsupported retained representations remain guarded for host recovery. Back up the save before any manual repair.

KV items preserve all accepted contents and absolute simulation-tick deadlines, including carried time. No timer restarts on replacement. A synchronized retained-state audit requires the key index and content inventory to match one-to-one; corrupt data is kept inert, never reclaimed or mined through a partial index. Monitor items preserve scale, palette, foreground/background colors and blink setting, not an obsolete merged-screen image or cursor. New grouping creates a blank image. Existing ordinary saves preserve live display models and logical identities.

## Upgrading from alpha 0.1.1

Back up the entire save and old mod ZIP before upgrading. The redesigned devices
use new circuit-capable shells without changing public Lua v1, logical IDs or
recipe/item names. During the mod configuration change, existing bodies are
converted only after replacement power, sockets and every role/color wire have
been staged. Data, absolute KV deadlines, live monitor contents, active runs and
unsaved recovery drafts are retained; conversion does not run startup again.
Existing editor sessions must be reopened against the new physical body.

Old tagged material items still restore their committed data into a fresh stopped
identity. Old blueprints still restore saved source/settings and native wires,
not application state or database contents. No extra socket items are required.

If conversion is refused, the old device/data/wires remain and an upgrade
refusal diagnostic is logged. Keep the backup and report the error; do not mine,
delete or reset retained data to force conversion. After the underlying cause is
repaired, conversion can be retried by a synchronized host action or a subsequent
mod configuration change. Rollback means restoring the complete backup with the
old mod, not loading an upgraded save in the old version.

## Blueprints, clones and settings copy

Blueprints include saved source and labels. These can themselves contain private literals. The blueprint description visibly discloses source inclusion. Application state, KV data, active source/run, registrations, output banks and managed target IDs are excluded. Inspect or remove source before sharing a blueprint.

New blueprints attach Network wires directly to the shell; native auxiliary socket ghosts carry the other role wires, so the engine rotates their coordinates and transfers red/green wires on revival. Hidden uncraftable port tokens exist only to make these native blueprint ghosts valid; do not craft or supply additional devices for them. Building the body revives its owned helpers without consuming more items. Helpers cannot be independently mined, deconstructed or operated. Externally placed/revived unowned helpers are destroyed rather than becoming usable orphans.

Entity and area clones receive fresh identities: computers stopped with saved source/label but empty state/work, KV empty, logic zero/unowned, monitors blank with applicable settings. Native area-cloned helpers are matched to the exact new body/source family and position, then adopted under bounded synchronized maintenance; duplicate/unmatched helpers are removed. This does not authorize an unrelated entity by position alone.

Settings copy stops the destination computer and copies saved source/label, not the source computer's state or active execution. Existing destination state is retained rather than implicitly reset. Its source revision advances monotonically so an older open draft cannot silently overwrite the copied source. Monitor settings copy changes the selected group's settings. KV data and native target configuration are never copied by the peripheral's settings operation.

Force changes and force merging revoke prior run authority and stop affected computers without erasing data. Surviving native factory configuration is not rolled back. Surface deletion/clearing retires the surface's exact identities and helpers. Cross-surface machine transport in the pinned engine is tested through native cloning: LuaEntity.teleport does not support surface teleport for these machine types. No same-identity cross-surface teleport claim is made.

## Verification

Use the deterministic archive with the existing harness:

    python3 tools/smoke.py --factorio /path/to/factorio --archive /outside/repo/tweaked-computers_0.1.0.zip --output /outside/repo/fresh-lifecycle --fixture tests.lifecycle_engine --production-context --cold --upgrade-fixture

Production-context mode loads this fixed fixture at control parsing only when the isolated tc-smoke mod and its explicit startup setting are present. Exactly one mod registry owns the native build/clone/revival events; no guest loader or remote API is added. Ordinary gameplay has no on_load handler and executes no player source on load. The fixture's on_load only checks retained aliases/counters.

Headless native robot mining, blueprints/ghost revival, cloning, destruction, force/surface events and separate-process load/configuration checks are distinct from table-backed editor/player delivery. Neither is graphical/client evidence. Production work ceilings remain unchanged and provisional; explicit fixture stepping is structural lifecycle evidence, not a real-time responsiveness benchmark.
